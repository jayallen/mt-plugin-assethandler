package AssetHandler::Tool::Import;

use strict;
use warnings;
use Pod::Usage;
use Data::Dumper;
use File::Spec;
use MT::Util qw( caturl );
use base qw( MT::App::CLI );
use Cwd qw( realpath );

# use MT::Log::Log4perl qw(l4mtdump); use Log::Log4perl qw( :resurrect );
###l4p our $logger = MT::Log::Log4perl->new();

use AssetHandler::Util;

sub option_spec {
    return (
        'blog|b=s', 'path=s@', 'recurse!',
        'excludeext|e=s@', 'includeext|i=s@',
        'url|u=s',
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

    $app->show_usage() unless @ARGV;

    $app->SUPER::init_options(@_) or return;
    my $opt = $app->options || {};


    $opt->{path} = \@ARGV if @ARGV and ! $opt->{path};
    foreach ( qw( blog path )) {
        return $app->error('Required attribute --'.$_.' not specified')
            unless defined $opt->{$_};
    }

    if ( @{$opt->{path}} > 1 and $opt->{url} ) {
        return $app->error(
            'You cannot use the --url argument with multiple paths.'
        );
    }

    ###l4p $logger->debug('$opt: ', l4mtdump( $opt ));
    1;
}

sub mode_default {
    my $app     = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    my $blog    = $app->blog();
    my $blog_id = $blog->id;
    my @paths   = $app->param('path');
    my $recurse = $app->param('recurse');
    my $plugin  = MT->component('AssetHandler');

    my $load_params;
    $load_params->{$_} = $app->param($_)
        for qw( recurse includeext excludeext );

    my @files;
    foreach my $path ( @paths ) {
        unless ( File::Spec->file_name_is_absolute( $path ) ) {
            $path = File::Spec->catfile(
                $blog->site_path,
                File::Spec->canonpath( $path )
            );
        }
        $path = realpath( $path );
        ###l4p $logger->debug('Inspecting path for files: '. $path);
        
        if ( -d $path ) {
            push @files,
                AssetHandler::Util::files_from_directory( 
                    $path,
                    $load_params
                );
        }
        elsif ( -f $path ) {
            push @files, $path;
        }
        else {
            warn "Skipping unknown path argument: $path";
        }
    }

    my @imported;
    my $url       = $app->param('url');
    my $root_path = $url ? $paths[0] : $blog->site_path;
    foreach my $file_path ( @files ) {
        (my $file_relpath = $file_path) =~ s{^$root_path}{};
        require AssetHandler::Util;
        my $asset = AssetHandler::Util::create_asset(
            $app,
            {
                file_path => $file_path,
                url       => caturl( $url || $blog->site_url, 
                                     $file_relpath ),
            }
        );
        push @imported, $asset;
        $app->print(
            $plugin->translate(
                "Imported '[_1]'\n",
                $file_path
            )
        );
    }
    return "Imported ".@imported." assets\n";
}

sub show_usage { 
    my $app = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    pod2usage(@_ ? @_ : { -exitval => 1, -verbose => 0 });
}

sub show_options { 
    my $app = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    pod2usage(@_ ? @_ : { -exitval => 1, -verbose => 1 });
}

sub show_docs {
    my $app = shift;
    ###l4p $logger ||= MT::Log::Log4perl->new(); $logger->trace();
    pod2usage(@_ ? @_ : { -exitval => 1, -verbose => 2 });
}

1;

__END__
