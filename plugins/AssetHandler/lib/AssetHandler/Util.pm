package AssetHandler::Util;

use File::Spec;
use DirHandle;

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
            next if $params->{exclude_ext}
                and -f $absfile
                and $file =~ m{\.$params->{exclude_ext}$}i;
            next if $params->{include_ext}
                and -f $absfile
                and $file !~ m{\.$params->{include_ext}$}i;
            push @files,
                -d $absfile ? files_from_directory( $absfile, $params )
                            : $absfile;
        }
        undef $d;
    }
    else {
        die "Can't open $path: $!";
    }

    return sort @files;
}
   # is_directory  => 1,
   #  path          => $path,
   #  url           => $url,
   #  file_basename => $file,
   #  full_path     => $path . $file,
   #  full_url      => $url . $file

sub process_import {
    my $app        = shift;
    my ($param)    = @_;
    my $blog_id    = $app->param('blog_id');
    my $local_file = $param->{full_path};
    my $url        = $param->{full_url};
    my $bytes      = -s $local_file;

    require MT::Blog;
    my $blog = MT::Blog->load($blog_id);

    require File::Basename;
    my $local_basename = File::Basename::basename($local_file);
    my $ext =
      ( File::Basename::fileparse( $local_file, qr/[A-Za-z0-9]+$/ ) )[2];

    # Copied mostly from MT::App::CMS

    my ( $fh, $mimetype );
    open $fh, $local_file;

    ## Use Image::Size to check if the uploaded file is an image, and if so,
    ## record additional image info (width, height). We first rewind the
    ## filehandle $fh, then pass it in to imgsize.
    seek $fh, 0, 0;
    eval { require Image::Size; };
    return $app->error(
        $app->translate(
                "Perl module Image::Size is required to determine "
              . "width and height of uploaded images."
        )
    ) if $@;
    my ( $w, $h, $id ) = Image::Size::imgsize($fh);

    ## Close up the filehandle.
    close $fh;

    require MT::Asset;
    my $asset_pkg = MT::Asset->handler_for_file($local_basename);
    my $is_image =
         defined($w)
      && defined($h)
      && $asset_pkg->isa('MT::Asset::Image');
    my $asset;
    if (!(  $asset = $asset_pkg->load(
                { file_path => $local_file, blog_id => $blog_id }
            )
        )
      )
    {
        $asset = $asset_pkg->new();
        $asset->file_path($local_file);
        $asset->file_name($local_basename);
        $asset->file_ext($ext);
        $asset->blog_id($blog_id);
        $asset->created_by( $app->user->id );
    }
    else {
        $asset->modified_by( $app->user->id );
    }
    my $original = $asset->clone;
    $asset->url($url);
    if ($is_image) {
        $asset->image_width($w);
        $asset->image_height($h);
    }
    $asset->mime_type($mimetype) if $mimetype;
    $asset->save;
    $app->run_callbacks( 'cms_post_save.asset', $app, $asset, $original );

    if ($is_image) {
        $app->run_callbacks(
            'cms_upload_file.' . $asset->class,
            File  => $local_file,
            file  => $local_file,
            Url   => $url,
            url   => $url,
            Size  => $bytes,
            size  => $bytes,
            Asset => $asset,
            asset => $asset,
            Type  => 'image',
            type  => 'image',
            Blog  => $blog,
            blog  => $blog
        );
        $app->run_callbacks(
            'cms_upload_image',
            File       => $local_file,
            file       => $local_file,
            Url        => $url,
            url        => $url,
            Size       => $bytes,
            size       => $bytes,
            Asset      => $asset,
            asset      => $asset,
            Height     => $h,
            height     => $h,
            Width      => $w,
            width      => $w,
            Type       => 'image',
            type       => 'image',
            ImageType  => $id,
            image_type => $id,
            Blog       => $blog,
            blog       => $blog
        );
    }
    else {
        $app->run_callbacks(
            'cms_upload_file.' . $asset->class,
            File  => $local_file,
            file  => $local_file,
            Url   => $url,
            url   => $url,
            Size  => $bytes,
            size  => $bytes,
            Asset => $asset,
            asset => $asset,
            Type  => 'file',
            type  => 'file',
            Blog  => $blog,
            blog  => $blog
        );
    }

}



1;

__END__

use strict;
use File::Find ();

# for the convenience of &wanted calls, including -eval statements:
use vars qw/*name *dir *prune/;
*name   = *File::Find::name;
*dir    = *File::Find::dir;
*prune  = *File::Find::prune;

sub wanted;



# Traverse desired filesystems
File::Find::find({wanted => \&wanted}, '/Users/jay/Sites/filmcritic.local/html/images');
exit;


sub wanted {
    my ($dev,$ino,$mode,$nlink,$uid,$gid);

    (($dev,$ino,$mode,$nlink,$uid,$gid) = lstat($_)) &&
    -f _
    && /^.*\\.gif\z/s
    && print("$name\n");
}
##########################################################