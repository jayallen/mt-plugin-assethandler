# package AssetHandler::Tool;
# 
# use strict;
# use warnings;
# use Data::Dumper;
# use Pod::Usage;
# use Getopt::Long qw( :config auto_version auto_help );
# 
# 
# BEGIN {
#     use File::Spec;
#     my $baselib = $ENV{MT_HOME} ? $ENV{MT_HOME} : '';
#     unshift @INC, ($baselib ? File::Spec->catdir($baselib, $_) : $_) foreach qw(lib extlib);
# }
# 
# use base qw( MT::App::CLI );
# 
# our %opt;
# 
# sub options { }
# 
# # sub new {
# #     my $class = shift;
# #     $class->init( @_ );
# # }
# 
# 
# sub init {
#     my $app = shift;
#     my $args  = { @_ };
#     $app->SUPER::init( @_ );
#     # print __PACKAGE__.'::init with $args: '.Dumper($args);
# 
#     # $ENV{MT_HOME} and -d $ENV{MT_HOME}
#     #     or pod2usage("Please set the MT_HOME environment variable equal to "
#     #                 ."the absolute path to your MT/Melody installation");
#     # my ($mt_instance);
#     # if ($args->{init_app} or $args->{App}) {
#     #     my $instance_class  = $args->{App} || 'MT::App::CLI';
#     #     eval {
#     #         require MT::Bootstrap::CLI;
#     #         import MT::Bootstrap::CLI  (App => $instance_class);
#     #         $mt_instance = MT->instance;            
#     #     };
#     #     $@ and return __PACKAGE__->error(join(': ', 
#     #         "Could not instantiate $instance_class", ($@||undef)));
#     # }
#     # else {
#     #     require MT;
#     #     $mt_instance = MT->new(Config => CONFIG)
#     #         or return __PACKAGE__->error(join(': ', 
#     #         'Could not instantiate MT', (MT->errstr||undef)));
#     # }
#     # return $mt_instance;
# 
#     # $class->show_usage(), exit if !$opts_good;
# 
#      #  => sub { $class->show_usage(); $class->show_help(); exit; },    
#      # => sub { pod2usage(0) },
# }
# 
# 1;
# 
# __END__
# 
# 
# =head1 AssetHandler::Tool
# 
# sample - Using GetOpt::Long and Pod::Usage
# 
# =head1 SYNOPSIS
# 
# sample [options] [file ...]
# 
#  Options:
#    -help            brief help message
#    -man             full documentation
# 
# =head1 OPTIONS
# 
# =over 8
# 
# =item B<-help>
# 
# Print a brief help message and exits.
# 
# =item B<-man>
# 
# Prints the manual page and exits.
# 
# =back
# 
# =head1 DESCRIPTION
# 
# B<This program> will read the given input file(s) and do something
# useful with the contents thereof.
# 
# =cut
# 
