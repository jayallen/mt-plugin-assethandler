package AssetHandler::Tool::Import;

use strict;
use warnings;
use Pod::Usage;
use Data::Dumper;
use File::Spec;
use MT::Util qw( caturl );
use base qw( MT::App::CLI );

use MT::Log::Log4perl qw(l4mtdump); use Log::Log4perl qw( :resurrect );
###l4p our $logger = MT::Log::Log4perl->new();

sub option_spec {
    return (
        'blog|b=s', 'path=s@', 'recurse!',
        'excludeext|e!', 'includeext|i!',
        $_[0]->SUPER::option_spec()
    );
}

sub init_request {
    my $app = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    $app->SUPER::init_request(@_) or return;

    my $blog = $app->load_by_name_or_id( 'blog', $app->param('blog') )
        or return;
    $app->param( 'blog_id', $blog->id );
    # print STDERR 'I just set $app->param( blog_id ) to '
    #            . $app->param( 'blog_id' ).": ".Dumper($app->blog());
        
    # $app->blog( $app->param('blog') );
}

sub init_options {
    my $app = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    $app->SUPER::init_options(@_) or return;
    my $opt = $app->options;
    foreach ( qw( blog path )) {
        return $app->error('Required attribute --'.$_.' not specified')
            unless defined $opt->{$_};
    }

    foreach ( @{ $opt->{path} } ) {
        -e $_ or return $app->error('Invalid --path attribute, path not found: '.$_);
    }
    1;
}

sub mode_default {
    my $app     = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    my $blog    = $app->blog();
    my $blog_id = $blog->id;
    my @paths   = $app->param('path');
    my $recurse = $app->param('recurse');
    my $url     = $app->param('url');
    my $plugin  = MT->component('AssetHandler');

    my $param = {
        blog_id   => $blog_id,
        button    => 'continue',
        path      => $path,
        url       => $url,
        readonly  => 1,
        blog_name => $blog->name
    };

    if ( -d $path ) {
        my @files = $app->param('file');

        # This happens on the first step
        if ( !@files ) {
            $param->{is_directory} = 1;
            $param->{files} = [ 
                map { file => $_ }
                        AssetHandler::Util::files_from_directory( $path )
            ];
        }
        else {

            # We get here if the user has chosen specific files to import
            $path .= '/' unless $path =~ m!/$!;
            $url  .= '/' unless $url  =~ m!/$!;

            print_transport_progress( $plugin, $app, 'start' );

            foreach my $file (@files) {
                next if -d ($path . $file); # Skip subdirectories for now

                _process_transport(
                    $app,
                    {   is_directory  => 1,
                        path          => $path,
                        url           => $url,
                        file_basename => $file,
                        full_path     => $path . $file,
                        full_url      => $url . $file
                    }
                );
                $app->print(
                    $plugin->translate(
                        "Imported '[_1]'\n",
                        $path . $file
                    )
                );
            }

            print_transport_progress( $plugin, $app, 'end' );
        }
    }
    else {
        print_transport_progress( $plugin, $app, 'start' );

        _process_transport(
            $app,
            {   full_path => $path,
                full_url  => $url
            }
        );
        $app->print( $plugin->translate( "Imported '[_1]'\n", $path ) );

        print_transport_progress( $plugin, $app, 'end' );
    }

    return $app->build_page( $plugin->load_tmpl('transporter.tmpl'), $param );
          
}

sub show_usage { 
    my $app = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    pod2usage(@_ ? @_ : { -exitval => 1, -verbose => 1 });
}

sub show_docs {
    my $app = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    pod2usage(@_ ? @_ : { -exitval => 1, -verbose => 2 });
}



# Both Mason and MT store image metadata and their relationships to entries in the database but keep the images themselves on the filesystem.  Where they differ is in the degree of freedom afforded to and responsibility conferred upon the user over the storage location of the images:
# 
# * MT passively manages images by simply recording whatever arbitrary filesystem location the user chooses for the uploaded file
# * Mason actively manages images, offering no choice to the user but minimizing the probability of file collisions
# 
# The following is an example of a current, legacy image URL:
# 
#     http://example.com/data/UNIXTIME/IMAGE_FILENAME
# 
# The `UNIXTIME` portion of the URL/file path is derived from the creation date of the entry into which an image stored within is embedded and formatted as an epoch time-stamp.  If multiple files are uploaded and embedded in a single entry, they will all be stored in the same time-stamped directory.  Hence, each directory under `data` corresponds to one (or rarely, multiple) entries created at the date and time indicated by the time-stamp.
# 
# 
# Caption data for each image (if any) is still stored in the Mason database and is related to the image in some fashion (TBD).  This needs to be migrated into the MT asset record for the image as the asset description.
# 
# ### Requirements ###
# 
# 

1;

__END__


=head1 AssetHandler::Tool::Import

sample - Using GetOpt::Long and Pod::Usage

=head1 SYNOPSIS

sample [options] [file ...]

 Options:
   -help            brief help message
   -man             full documentation

=head1 OPTIONS

=over 8

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<This program> will read the given input file(s) and do something
useful with the contents thereof.

=cut

