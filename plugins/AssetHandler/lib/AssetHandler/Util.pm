package AssetHandler::Util;

use strict;
use warnings;
use File::Basename qw( basename fileparse );
# use MT::Log::Log4perl qw( l4mtdump ); use Log::Log4perl qw( :resurrect ); our $logger;

sub create_asset {
    my ( $app, $param ) = @_;
    ###l4p my $logger = MT::Log::Log4perl->new(); $logger->trace();
    require MT::Blog;
    require MT::Image;
    my $blog_id         = delete $param->{blog_id} || $app->param('blog_id');
    my $blog            = MT::Blog->load($blog_id);
    my $url             = delete $param->{url};
    my $file_path       = delete $param->{file_path};
    $param->{file_name} = basename( $file_path );
    my $asset_pkg
        = MT->model('asset')->handler_for_file( $param->{file_name} );

    # To test whether we have an image and to ensure that we don't have
    # a non-image with an image extension, we'll test for image size 
    my $is_image = 0;
    my ( $w, $h, $id );
    {
        my $fh;
        open $fh, $file_path;      # Lexically scoped $fh
        ( $w, $h, $id ) = MT::Image->check_upload( Fh => $fh );
    }
    if ( defined($w) && defined($h) ) {
        $is_image = 1
            if $asset_pkg->isa('MT::Asset::Image');
    }
    else {
        # Wrong $asset_pkg, rebless to generic
        $asset_pkg = 'MT::Asset'
            if $asset_pkg->isa('MT::Asset::Image');
    }

    # Before attempting to load an existing asset, abbreviate the
    # file_path using the blog site root placeholder, %r, if the 
    # asset lives under the blog site root.
    (my $blog_root       = $blog->site_path) =~ s{/?$}{}g;
    my $abbrev_file_path = $file_path;
    $abbrev_file_path    =~ s{^$blog_root}{%r};

    # get_by_key loads the object or auto-instantiates a 
    # new one if none exist with the given \%terms
    my $asset = $asset_pkg->get_by_key({
        file_path => $abbrev_file_path,
        blog_id   => $blog_id
    });
    my $original = $asset->clone;  # For callbacks

    if ( ! $asset->id ) {
        # New object, set the other values
        $asset->set_values( $param );

        $asset->label( $param->{file_name} ) unless defined $asset->label;

        $asset->created_by( $app->user->id )
            if $app->can('user') and $app->user;

        $asset->file_ext(
            ( fileparse( $file_path, qr/[A-Za-z0-9]+$/ ) )[2]
        );
    }
    else {
        # Existing object, update modified by because
        # we'll re-evaluate and update some columns
        $asset->modified_by( $app->user->id );
    }

    if ( $is_image ) {
        $asset->image_width($w);
        $asset->image_height($h);
    }

    unless ( $url =~ m{^\%r} ) {
        (my $blog_url  = $blog->site_url) =~ s{/?$}{}g;
        (my $asset_url = $url)            =~ s{^$blog_url}{%r};
        $asset->url( $asset_url );
    }

    unless ( $asset->mime_type ) {
        require LWP::MediaTypes;
        $asset->mime_type(
            LWP::MediaTypes::guess_media_type($asset->file_path)
        );
    }

    ### SAVE ASSET
    ###l4p $logger->debug('Saving $asset: ', l4mtdump($asset));
    $asset->save
        or die sprintf "Could not save asset %s: %s",
            $asset->file_name, $asset->errstr;
    ###l4p $logger->debug('Asset SAVED');

    #
    # Asset Callbacks
    #
    my %cb_params = (
        Asset => $asset,
        Blog  => $blog,
        Url   => $url,
        File  => $file_path,
        Size  => -s $file_path,
        Type  => 'image',  # Overridden for non-images
    );
    # Create lower-cased keys
    $cb_params{lc($_)} = $cb_params{$_} foreach keys %cb_params;

    my @cb_types = ( 'api', ( $app->isa('MT::App::CMS') ? 'cms' : () ));
    foreach my $cb_type ( @cb_types ) {
        $app->run_callbacks( $cb_type.'_post_save.asset',
                             $app, $asset, $original );
        if ($is_image) {
            $app->run_callbacks(
                $cb_type.'_upload_file.' . $asset->class,
                %cb_params
            );
            $app->run_callbacks(
                $cb_type.'_upload_image',
                Height     => $h,
                height     => $h,
                Width      => $w,
                width      => $w,
                ImageType  => $id,
                image_type => $id,
                %cb_params
            );
        }
        else {
            $app->run_callbacks(
                $cb_type.'_upload_file.' . $asset->class,
                %cb_params,
                Type  => 'file',  # Overriding
                type  => 'file',  # Overriding
            );
        }
    }
    return $asset;
}

1;