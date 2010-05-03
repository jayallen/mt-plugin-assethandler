#!/usr/bin/perl

use strict;
use warnings;
use Carp qw( longmess );
use File::Spec;
use File::Path qw( make_path remove_tree );
use File::Copy::Recursive qw(fcopy rcopy dircopy fmove rmove dirmove);
use Data::Dumper;
use FindBin qw($Bin);
use lib "$Bin/lib",    't/lib',  't',
        "$Bin/../lib", 'lib',    'extlib';

use Test::More tests => 3;

use MT::Test qw( :DEFAULT );
use AssetHandler::Test;
use AssetHandler::Util;

use vars qw( $src_images_dir $site_dir $site_images_dir
             $app $blog $DB_DIR $T_CFG );

$src_images_dir  = File::Spec->catdir($Bin, 'images' );
$site_dir        = File::Spec->catdir($ENV{MT_HOME}, 't', 'site' );
$site_images_dir = File::Spec->catdir($site_dir, 'images' );

# Initialize the database and app
ok(
    $app = AssetHandler::Test->setup('data', 'app', 'images'),
    'Data initialized'
); #1
is( ref $app, 'MT', 'MT app initialized'); #2
ok( -f File::Spec->catdir( $site_images_dir, 'stella.jpg' ),
    'Image directory initialized'); #3


# $imagesrc_dir = File::Spec->catdir($Bin, 'images' );
# $site_dir     = File::Spec->catdir($ENV{MT_HOME}, 't', 'site' );
# $images_dir   = File::Spec->catdir($site_dir, 'images' );


# sub option_spec {
#     return (
#         'blog|b=s', 'path=s@', 'recurse!',
#         'excludeext|e=s@', 'includeext|i=s@',
#         'url|u=s',
#         $_[0]->SUPER::option_spec()
#     );
# }
# 
# sub init_options {
#     my $app = shift;
#     ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
# 
#     $app->show_usage() unless @ARGV;
# 
#     $app->SUPER::init_options(@_) or return;
#     my $opt = $app->options || {};
# 
# 
#     $opt->{path} = \@ARGV if @ARGV and ! $opt->{path};
#     foreach ( qw( blog path )) {
#         return $app->error('Required attribute --'.$_.' not specified')
#             unless defined $opt->{$_};
#     }
# 
#     if ( @{$opt->{path}} > 1 and $opt->{url} ) {
#         return $app->error(
#             'You cannot use the --url argument with multiple paths.'
#         );
#     }
# 
#     ###l4p $logger->debug('$opt: ', l4mtdump( $opt ));
#     1;
# }
# 
# 
# 
# =head1 SYNOPSIS
# 
#  ./plugins/AssetHandler/tools/import [options] [PATH [PATH...]]
# 
# Use the --help flag for more information
# 
# =head1 OPTIONS
# 
# =over 8
# 
# 
# =item B<-b, --blog (ID|NAME)>
# 
# The ID or exact name of the blog to be used for import
# 
# =item B<-r, --recurse>
# 
# When a directory is specified as a path argument, this flag directs
# the program to search its subdirectories recursively for import
# files.
# 
# =item B<-u, --url URL>
# 
# Specifies the URL corresponding to a single --path argument. This
# defaults to the blog URL so you should only need to specify this if
# the import path is outside of your blog root URL or if you want to
# use a special URL to access the assets (e.g. a subdomain like
# http://images.example.com for all images). This argument may only be
# used with one import path at a time and must correspond exactly with
# that path.
# 
# =item B<-e, --excludeext EXT>
# 
# Specifies a file extension (case-insensitive) to exclude when
# searching for files to import. Can be specified multiple times.
# 
# =item B<-i, --includeext EXT>
# 
# The exact inverse of --excludeext. Specifies a file extension
# (case-insensitive) to include when searching for files to import.
# Can be specified multiple times.
# 
# =item B<-h>
# 
# Prints a brief usage message.
# 
# =item B<--help>
# 
# Displays the command usage and option descriptions.
# 
# =item B<--man>
# 
# Displays the full manual page including, most notably, examples of usage.
# 
# =back
# 
# =head1 DESCRIPTION
# 
# This program imports assets into Melody/Movable Type specified by one or
# more path arguments which can be either files or directories.
# 
# =head1 SETTING YOUR MT_HOME ENVIRONMENT VARIABLE
# 
# For all examples shown below, it is assumed that you have properly set your
# MT_HOME environment variable. With this set, you are free to run this
# program from anywhere, not just your MT directory.
# 
# Setting MT_HOME is usually done through one of the following methods:
# 
# =over 8
# 
# =item B<Export declaration:> 
# 
#  prompt> export MT_HOME="/home/www/cgi-bin/mt"
#  prompt> /path/to/script [options] args
# 
# =item B<Temporary assignment:>
# 
#   prompt> MT_HOME="/path/to/MT" /path/to/script [options] args
# 
# =back
# 
# If you only have a single MT directory, it's best to use an export
# declaration in your shell's init script (e.g. .bashrc/.bash_profile,
# .cshrc, etc).
# 
# =head1 EXAMPLES
# 
# Both of the following import all files in the "images" directory at the
# root of the blog ID 4.
# 
#     /path/to/import -b 4 images
#     /path/to/import -b 4 /path/to/blog4/images
# 
# The following imports all files found within the "images" directory (I<and>
# its subdirectories) at the root of the "Cartoon Corner" blog.
# 
#     /path/to/import -r -b "Cartoon Corner" images
# 
# The following imports all JPG files found within the "images", "pictures"
# and "photos" directories (I<and> subdirectories) at the root of the blog ID
# 12.
# 
#         /path/to/import -b 12 -i jpg -r images pictures photos
# 
# The following recursively imports all files found in
# "/home/www/shared/images" into blog ID 42 using the URL
# http://media.example.com which corresponds to the specified path
# 
#     /path/to/import -b 42 --url http://media.example.com/  \
#                     -r /home/www/shared/images
# 
# =cut
# 
