package AssetHandler::Test;

use base qw( MT::ErrorHandler );
use MT;

use lib 't/lib', 't';

my $mt;
BEGIN {
    require 'test-common.pl';
}

sub setup {
    my $self  = shift;
    my %thang = map { $_ => 1 } @_;

    eval {

        if ( $thang{data} ) {
            print STDERR "Initializing DB";
            MT::Test->init_db();
            delete $thang{db};
            my $entry_class = MT->model('entry');
            unless ( MT->product_code eq 'OM' ) {
                no strict 'refs';
                *{$entry_class."::set_defaults"} = \&set_defaults;
            }
            print STDERR ", Data";
            MT::Test->init_data();
            delete $thang{data};
        
        }
        elsif ( $thang{db} ) {
            print STDERR "Initializing DB";
            MT::Test->init_db();
            delete $thang{db};
        }
        else {
            print STDERR "Initializing MT";
            $mt = MT->new( CONFIG => $ENV{MT_CONFIG} )
              or die "No MT object " . MT->errstr;

            my $types = MT->registry('object_types');
            $types->{$_} = MT->model($_)
              for grep { MT->model($_) }
              map      { $_ . ':meta' }
              grep     { MT->model($_)->meta_pkg }
              sort keys %$types;
            my @classes = map { $types->{$_} }
                            grep { $_ !~ /\./ }
                                sort keys %$types;
            foreach my $class (@classes) {
                if ( ref($class) eq 'ARRAY' ) {
                    next;    #TODO for now - it won't hurt when we do driver-tests.
                }
                elsif ( !defined *{ $class . '::__properties' } ) {
                    eval '# line ' 
                      . __LINE__ . ' ' 
                      . __FILE__ . "\n"
                      . 'require '
                      . $class
                      or die $@;
                }
            }

            # Init DB driver handle
            my $driver = MT::Object->driver();
            my $dbh = $driver->rw_handle;
        }

        foreach my $thang ( grep { $_ !~ /^(data|db)$/ } @_ ) {
            print STDERR ", $thang";
            next unless my $meth = MT::Test->can('init_'.$thang)
                                 || $self->can('init_'.$thang);
            $meth->();
        }
        print STDERR "\n";
    };
    $@ and die "There was an error initializing the test data: $@\n";
    return $mt ||= MT->instance;
}

sub set_defaults {
    my $e    = shift or return;
    my $app  = MT->instance;
    my $blog = $e->blog;
    my $user = $e->author;

    # If we have an $app fill in missing values from it if possible.
    # $app can be a non-MT::App object so we have to check for methods
    if ( $app ) {
        $blog ||= $app->blog if $app->can('blog');
        $user ||= $app->user if $app->can('user');
    }

    # Set correct class for objects that subclass Entry
    my $class = $e->properties->{defaults}{class} || 'entry';

    my (%entry_defaults, %user_defaults, %blog_defaults);
    
    %entry_defaults = (
        ping_count => 0,
        comment_count => 0,
        class      => $class,
        status     => HOLD,
    );

    if ( $user ) { 
        %user_defaults = (
            author_id      => $user->id,
            convert_breaks => ($user->text_format || ''),
        );
    }

    if ( $blog ) {
        %blog_defaults = (
            status         => $blog->status_default,
            allow_comments => $blog->allow_comments_default,
            allow_pings    => $blog->allow_pings_default,
            convert_breaks => ($blog->convert_paras || '__default__'),
        );
        delete $blog_defaults{convert_breaks}
            if $user_defaults{convert_breaks};
    }
    
    $e->set_values({ %entry_defaults, %user_defaults, %blog_defaults });
}

sub init_images {

    my $src_images_dir = File::Spec->catdir(
        $ENV{MT_HOME}, 
        'plugins',
        'AssetHandler',
        't',
        'images'
    );
    my $site_dir        = File::Spec->catdir($ENV{MT_HOME}, 't', 'site' );
    my $site_images_dir = File::Spec->catdir($site_dir, 'images' );

    require File::Path; import File::Path qw( remove_tree );
    require File::Copy::Recursive; import File::Copy::Recursive qw( dircopy );

    # Copy the images directory to the site directory,
    # removing an existing one if it's there
    remove_tree( $site_images_dir, { safe => 1 } );
    dircopy( $src_images_dir, $site_images_dir );    
}

1;

