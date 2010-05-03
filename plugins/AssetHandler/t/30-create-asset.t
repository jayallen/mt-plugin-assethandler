#!/usr/bin/perl

use strict;
use warnings;
use Carp qw( longmess );
use File::Spec;
use File::Path qw( make_path remove_tree );
use File::Copy::Recursive qw(fcopy rcopy dircopy fmove rmove dirmove);
use Data::Dumper;
use FindBin qw($Bin);
use lib "$Bin/lib",    't/lib',
        "$Bin/../lib", 'lib',    'extlib';


use Test::More tests => 16;

use MT::Test; # Gives us is_object(), are_objects(), _run_app(), out_like(), out_unlike(), err_like(), grab_stderr(), get_current_session(), _tmpl_out(), tmpl_out_like(), tmpl_out_unlike(), get_last_output(), get_tmpl_error(), get_tmpl_out(), _run_rpt() and _run_tasks();

use AssetHandler::Test;
use AssetHandler::Util;

my $src_img_dir     = File::Spec->catdir($Bin, 'images' );
my $site_dir        = File::Spec->catdir($ENV{MT_HOME}, 't', 'site' );
my $site_images_dir = File::Spec->catdir($site_dir, 'images' );

my $app = AssetHandler::Test->setup(qw( db data app images ));

my $blog = eval { MT->model('blog')->load(1) };
$@ or ! defined $blog
    and die "Could not load blog ID 1: ".($@||MT->model('blog')->errstr);

my $url;
my $file_path = File::Spec->catdir( $site_images_dir, 'stella.jpg' );
die "Cannot find $file_path" unless -f $file_path;

my $asset = AssetHandler::Util::create_asset(
    $app,
    {
        blog_id   => $blog->id,
        file_path => $file_path,
        url       => 'http://whatever.com/images/stella.jpg'
    }
);
my $test_asset = MT->model('image')->load({ file_path => $file_path });

ok( $asset,                             'Asset object created'      ); #1
is( $asset->id, 3,                      'Asset object saved'        ); #2
is( ref $asset, 'MT::Asset::Image',     'Asset parent class'        ); #3
ok( $test_asset,                        'Asset loaded from database'); #4
is_object( $test_asset, $asset, 'Created asset matches loaded asset'); #5
is( $asset->file_ext, 'jpg',            'Asset file extension'      ); #6
ok( ! defined $asset->parent,           'Undefined asset parent'    ); #7
is( $asset->blog_id, 1,                 'Asset blog ID'             ); #8
is( $asset->label, 'stella.jpg',        'Asset label'               ); #9
is( $asset->class, 'image',             'Asset class'               ); #10
ok( ! defined $asset->description,      'Asset description'         ); #11
is( $asset->mime_type, 'image/jpeg',    'Asset MIME type'           ); #12
is( $asset->file_name, 'stella.jpg',    'Asset file name'           ); #13
is( $asset->url, 'http://whatever.com/images/stella.jpg','Asset URL');#14
is( $asset->image_width, '630',         'Asset width'               ); #15
is( $asset->image_height, '420',        'Asset height'              ); #16

exit;




# 
#   'file_ext' => 'jpg',
#   'file_path' => '/Users/jay/code/omt/mt-plugin-assethandler/plugins/AssetHandler/t/images/stella.jpg',
#   'parent' => undef,
#   'description' => undef,
#   'mime_type' => 'image/jpeg',
#   'file_name' => 'stella.jpg',
#   'modified_on' => '20100503003706',
#   'created_on' => '20100503003706',
#   'modified_by' => undef,
#   'url' => 'http://whatever.com/images/stella.jpg',
#   'blog_id' => 1,
#   'id' => 3,
#   'label' => 'stella.jpg',
#   'class' => 'image',
#   'created_by' => undef
# },

# my @files = [
#     {
#         url       => 'http://',
#         file_path => ''
#     }
# ];
# 
# my $url       = $app->param('url');
# my $root_path = $url ? $paths[0] : $blog->site_path;
# foreach my $file_path ( @files ) {
#     (my $file_relpath = $file_path) =~ s{^$root_path}{};
#     require AssetHandler::Util;
#     my $asset = AssetHandler::Util::create_asset(
#         $app,
#         {
#             file_path => $file_path,
#             url       => caturl( $url || $blog->site_url, 
#                                  $file_relpath ),
#         }
#     );
# }
