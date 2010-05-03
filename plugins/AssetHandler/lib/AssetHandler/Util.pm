package AssetHandler::Util;

use strict;
use warnings;
use File::Basename qw( basename fileparse );
use File::Spec;
use DirHandle;
use Data::Dumper;
# use MT::Log::Log4perl qw( l4mtdump ); use Log::Log4perl qw( :resurrect ); our $logger;

sub create_asset {
    my ( $app, $param ) = @_;
    ###l4p my $logger = MT::Log::Log4perl->new(); $logger->trace();
    require MT::Blog;
    require MT::Image;
    my $url       = delete $param->{url};
    my $file_path = delete $param->{file_path};
    my $user      = $app->user if $app->can('user');
    my $blog      = $param->{blog}      ? delete $param->{blog}
                  : $app->can('param')  ? $app->param('blog')
                                        : undef;
    
    unless ( ref $blog and $blog->isa('MT::Blog') ) {
        my $blog_id   = $blog               ? $blog
                      : $param->{blog_id}   ? delete $param->{blog_id}
                      : $app->can('param')  ? $app->param('blog_id')
                                            : undef;
        $blog = MT->model('blog')->load( $blog_id ) if $blog_id;
    }
                
    unless ( $blog && $url && $file_path ) {
        warn "The blog, url and path parameters are required";
        return undef;
    }

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
    (my $blog_root        = $blog->site_path) =~ s{/?$}{}g;
    (my $abbrev_file_path = $file_path)       =~ s{^$blog_root}{%r};

    (my $blog_url   = $blog->site_url)  =~ s{/?$}{}g;
    (my $abbrev_url = $url)             =~ s{^$blog_url}{%r};

    my @assets = $asset_pkg->load([ 
        { blog_id   => $blog->id, file_path => $abbrev_file_path }
            => -or =>
        { blog_id   => $blog->id, file_path => $file_path }
    ]);

    if ( @assets > 1 ) {
        warn sprintf 'Possibly duplicate asset records in blog %s '
                    .'with file path %s', $blog->id, $assets[0]->file_path;
    }

    my $asset    = shift @assets || $asset_pkg->new();
    my $original = $asset->clone;  # For callbacks
    return if $asset->id;

    # New object, set the other values
    $asset->set_values( $param );
    $asset->blog_id( $blog->id );
    $asset->file_path( $abbrev_file_path );
    $asset->url( $abbrev_url );
    $asset->label( $param->{file_name} ) unless defined $asset->label;
    $asset->created_by( $user ) if $user;
    $asset->file_ext(
        ( fileparse( $file_path, qr/[A-Za-z0-9]+$/ ) )[2]
    );

    if ( $is_image ) {
        $asset->image_width($w);
        $asset->image_height($h);
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


sub files_from_directory {
    my ($path, $params) = @_;
    $params           ||= {};
    my @files;
    my $dir = new DirHandle $path;
    if (defined $dir) {
        # print STDERR "Inspecting directory: $path\n";
        while ( defined( my $file = $dir->read )) {
            my $absfile = File::Spec->catfile( $path, $file );
            next if $file =~ m{^\.\.?$};
            next if ! $params->{recurse} and -d $absfile;
            next if $params->{excludeext}
                and -f $absfile
                and $file =~ m{\.$params->{excludeext}$}i;
            next if $params->{includeext}
                and -f $absfile
                and $file !~ m{\.$params->{includeext}$}i;
            push @files,
                -d $absfile ? files_from_directory( $absfile, $params )
                            : $absfile;
        }
        undef $dir;
    }
    else {
        die "Can't open $path: $!";
    }

    return sort @files;
}

# sub process_import {
#     my $app        = shift;
#     my ($param)    = @_;
#     my $blog_id    = $app->param('blog_id');
#     my $local_file = $param->{full_path};
#     my $url        = $param->{full_url};
#     my $bytes      = -s $local_file;
# 
#     require MT::Blog;
#     my $blog = MT::Blog->load($blog_id);
# 
#     require File::Basename;
#     my $local_basename = File::Basename::basename($local_file);
#     my $ext =
#       ( File::Basename::fileparse( $local_file, qr/[A-Za-z0-9]+$/ ) )[2];
# 
#     # Copied mostly from MT::App::CMS
# 
#     my ( $fh, $mimetype );
#     open $fh, $local_file;
# 
#     ## Use Image::Size to check if the uploaded file is an image, and if so,
#     ## record additional image info (width, height). We first rewind the
#     ## filehandle $fh, then pass it in to imgsize.
#     seek $fh, 0, 0;
#     eval { require Image::Size; };
#     return $app->error(
#         $app->translate(
#                 "Perl module Image::Size is required to determine "
#               . "width and height of uploaded images."
#         )
#     ) if $@;
#     my ( $w, $h, $id ) = Image::Size::imgsize($fh);
# 
#     ## Close up the filehandle.
#     close $fh;
# 
#     require MT::Asset;
#     my $asset_pkg = MT::Asset->handler_for_file($local_basename);
#     my $is_image =
#          defined($w)
#       && defined($h)
#       && $asset_pkg->isa('MT::Asset::Image');
#     my $asset;
#     if (!(  $asset = $asset_pkg->load(
#                 { file_path => $local_file, blog_id => $blog_id }
#             )
#         )
#       )
#     {
#         $asset = $asset_pkg->new();
#         $asset->file_path($local_file);
#         $asset->file_name($local_basename);
#         $asset->file_ext($ext);
#         $asset->blog_id($blog_id);
#         $asset->created_by( $app->user->id );
#     }
#     else {
#         $asset->modified_by( $app->user->id );
#     }
#     my $original = $asset->clone;
#     $asset->url($url);
#     if ($is_image) {
#         $asset->image_width($w);
#         $asset->image_height($h);
#     }
#     $asset->mime_type($mimetype) if $mimetype;
#     $asset->save;
#     $app->run_callbacks( 'cms_post_save.asset', $app, $asset, $original );
# 
#     if ($is_image) {
#         $app->run_callbacks(
#             'cms_upload_file.' . $asset->class,
#             File  => $local_file,
#             file  => $local_file,
#             Url   => $url,
#             url   => $url,
#             Size  => $bytes,
#             size  => $bytes,
#             Asset => $asset,
#             asset => $asset,
#             Type  => 'image',
#             type  => 'image',
#             Blog  => $blog,
#             blog  => $blog
#         );
#         $app->run_callbacks(
#             'cms_upload_image',
#             File       => $local_file,
#             file       => $local_file,
#             Url        => $url,
#             url        => $url,
#             Size       => $bytes,
#             size       => $bytes,
#             Asset      => $asset,
#             asset      => $asset,
#             Height     => $h,
#             height     => $h,
#             Width      => $w,
#             width      => $w,
#             Type       => 'image',
#             type       => 'image',
#             ImageType  => $id,
#             image_type => $id,
#             Blog       => $blog,
#             blog       => $blog
#         );
#     }
#     else {
#         $app->run_callbacks(
#             'cms_upload_file.' . $asset->class,
#             File  => $local_file,
#             file  => $local_file,
#             Url   => $url,
#             url   => $url,
#             Size  => $bytes,
#             size  => $bytes,
#             Asset => $asset,
#             asset => $asset,
#             Type  => 'file',
#             type  => 'file',
#             Blog  => $blog,
#             blog  => $blog
#         );
#     }
# 
# }

1;

__END__

# use strict;
# use File::Find ();
# 
# # for the convenience of &wanted calls, including -eval statements:
# use vars qw/*name *dir *prune/;
# *name   = *File::Find::name;
# *dir    = *File::Find::dir;
# *prune  = *File::Find::prune;
# 
# sub wanted;
# 
# 
# 
# # Traverse desired filesystems
# File::Find::find({wanted => \&wanted}, '/Users/jay/Sites/filmcritic.local/html/images');
# exit;
# 
# 
# sub wanted {
#     my ($dev,$ino,$mode,$nlink,$uid,$gid);
# 
#     (($dev,$ino,$mode,$nlink,$uid,$gid) = lstat($_)) &&
#     -f _
#     && /^.*\\.gif\z/s
#     && print("$name\n");
# }
# ##########################################################
