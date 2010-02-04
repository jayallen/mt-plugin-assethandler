package AssetHandler::App::CMS;

use strict;
use warnings;
use MT::Util qw( format_ts relative_date caturl );

use MT 4.2;

# use MT::Log::Log4perl qw( l4mtdump ); use Log::Log4perl qw( :resurrect ); our $logger;
use AssetHandler::Util;

sub open_batch_editor {
    my ($app)      = @_;
    my $plugin     = MT->component('AssetHandler');
    my @ids        = $app->param('id');
    my $blog_id    = $app->param('blog_id');
    my $auth_prefs = $app->user->entry_prefs;
    my $tag_delim  = chr( $auth_prefs->{tag_delim} );

    require File::Basename;
    require JSON;
    # require MT::Author;
    require MT::Tag;

    my $hasher = sub {
        my ( $obj, $row ) = @_;
        my $blog = $obj->blog;
        $row->{blog_name} = $blog ? $blog->name : '-';
        $row->{file_path} = $obj->file_path;   # has to be called to calculate
        $row->{url} = $obj->url;    # this has to be called to calculate
        $row->{file_name} = File::Basename::basename( $row->{file_path} );
        my $meta = $obj->metadata;
        $row->{file_label} = $obj->label;

        if ( -f $row->{file_path} ) {
            my @stat = stat( $row->{file_path} );
            my $size = $stat[7];
            my ($thumb_file) =
              $obj->thumbnail_url( Height => 240, Width => 350 );
            $row->{thumbnail_url} = $meta->{thumbnail_url} = $thumb_file;
            $row->{asset_class}   = $obj->class_label;
            $row->{file_size}     = $size;
            if ( $size < 1024 ) {
                $row->{file_size_formatted} = sprintf( "%d Bytes", $size );
            }
            elsif ( $size < 1024000 ) {
                $row->{file_size_formatted} =
                  sprintf( "%.1f KB", $size / 1024 );
            }
            else {
                $row->{file_size_formatted} =
                  sprintf( "%.1f MB", $size / 1024000 );
            }
        }
        else {
            $row->{file_is_missing} = 1;
        }
        my $ts = $obj->created_on;

        # if ( my $by = $obj->created_by ) {
        #     my $user           = MT::Author->load($by);
        #     $row->{created_by} = $user ? $user->name : '';
        # }
        # if ($ts) {
        #     my %fmt = (
        #         created_on_formatted
        #             => MT::App::CMS::LISTING_DATE_FORMAT,
        #         created_on_time_formatted
        #             => MT::App::CMS::LISTING_TIMESTAMP_FORMAT,
        #     );
        #     foreach my $key ( keys %fmt ) {
        #         $row->{$key} = format_ts(
        #             $fmt{$key}, 
        #             $ts, 
        #             $blog, 
        #             $app->user ? $app->user->preferred_language : undef
        #         );
        #     }
        #     $row->{created_on_relative} = relative_date( $ts, time, $blog );
        # }

        $row->{metadata_json} = JSON::objToJson($meta);

        my $tags = MT::Tag->join( $tag_delim, $obj->tags );
        $row->{tags} = $tags;
    };

    require File::Spec;
    return $app->listing( {
            terms => { id => \@ids, blog_id => $app->param('blog_id') },
            args => { sort => 'created_on', direction => 'descend' },
            type => 'asset',
            code => $hasher,
            template => File::Spec->catdir(
                $plugin->path, 'tmpl', 'asset_batch_editor.tmpl'
            ),
            params => { (
                    $blog_id
                    ? ( blog_id      => $blog_id,
                        edit_blog_id => $blog_id,
                      )
                    : ( system_overview => 1 )
                ),
                saved => $app->param('saved') || 0,
                return_args => "__mode=list_assets&blog_id=$blog_id"
            }
        }
    );
}

sub save_assets {
    my ($app)      = @_;
    my $plugin     = MT->component('AssetHandler');
    my @ids        = $app->param('id');
    my $blog_id    = $app->param('blog_id');
    my $auth_prefs = $app->user->entry_prefs;
    my $tag_delim  = chr( $auth_prefs->{tag_delim} );

    require MT::Asset;
    require MT::Tag;

    foreach my $id (@ids) {
        my $asset = MT::Asset->load($id);
        $asset->label( $app->param("label_$id") );
        $asset->description( $app->param("description_$id") );

        if ( my $tags = $app->param("tags_$id") ) {
            my @tags = MT::Tag->split( $tag_delim, $tags );
            $asset->set_tags(@tags);
        }

        $asset->save
          or
          die $app->trans_error( "Error saving file: [_1]", $asset->errstr );
    }

    $app->call_return( saved => 1 );
}

sub start_transporter {
    my ($app) = @_;
    my $plugin = MT->component('AssetHandler');
    my $blog_id = $app->param('blog_id')
      or return $app->error('No blog in context for asset import');
    require MT::Blog;
    my $blog   = MT::Blog->load($blog_id);
    my $param;
    ($param->{path} = $blog->site_path) =~ s{/*$}{/};
    ($param->{url}  = $blog->site_url)  =~ s{/*$}{/};
    return $app->build_page( $plugin->load_tmpl('transporter.tmpl'), $param );
}

sub transport {
    my ($app)   = @_;
    ###l4p my $logger = MT::Log::Log4perl->new(); $logger->trace();
    my $path    = $app->param('path');
    my $url     = $app->param('url');
    my $plugin  = MT->component('AssetHandler');
    my $blog_id = $app->param('blog_id')
      or return $app->error('No blog in context for asset import');

    require MT::Blog;
    my $blog   = MT::Blog->load($blog_id);
    ###l4p $logger->debug('Blog ID: '.$blog->id);

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
            my @files;
            opendir( DIR, $path ) or die "Can't open $path: $!";
            while ( my $file = readdir(DIR) ) {
                next if $file =~ /^\./;
                push @files, { file => $file };
            }
            closedir(DIR);

            @files = sort { $a->{file} cmp $b->{file} } @files;
            $param->{files} = \@files;
        }
        else {
            # We get here if the user has chosen some specific files to import
            $path =~ s{/*$}{/};
            $url  =~ s{/*$}{/};

            print_transport_progress( $plugin, $app, 'start' );

            require File::Spec;
            foreach my $file (@files) {
                my $file_path = File::Spec->catfile( $path, $file );
                next if -d $file_path;    # Skip any subdirectories for now

                ###l4p $logger->info('About to import file: '.$file_path);
                require AssetHandler::Util;
                my $asset = AssetHandler::Util::create_asset(
                    $app,
                    {   
                        file_path => $file_path,
                        url       => caturl( $url, $file ),
                    }
                );
                ###l4p $logger->info(sprintf 'Back from create_asset with file %s. Asset ID %s', $asset->file_path, $asset->id);
                $app->print(
                    $plugin->translate(
                        "Imported '[_1]'\n",
                        $file_path
                    )
                );
            }

            print_transport_progress( $plugin, $app, 'end' );
        }
    }
    else {
        print_transport_progress( $plugin, $app, 'start' );

        require AssetHandler::Util;
        my $asset = AssetHandler::Util::create_asset(
            $app,
            {
                file_path => $path,
                url       => $url
            }
        );
        $app->print( $plugin->translate( "Imported '[_1]'\n", $path ) );

        print_transport_progress( $plugin, $app, 'end' );
    }

    return $app->build_page( $plugin->load_tmpl('transporter.tmpl'), $param );
}

sub print_transport_progress {
    my $plugin = shift;
    my ( $app, $direction ) = @_;
    $direction ||= 'start';

    if ( $direction eq 'start' ) {
        $app->{no_print_body} = 1;

        local $| = 1;
        my $charset = MT::ConfigMgr->instance->PublishCharset;
        $app->send_http_header(
            'text/html' . ( $charset ? "; charset=$charset" : '' ) );
        $app->print(
            $app->build_page( $plugin->load_tmpl('transporter_start.tmpl') )
        );
    }
    else {
        $app->print(
            $app->build_page( $plugin->load_tmpl('transporter_end.tmpl') ) );
    }
}

sub list_asset_src {
    my ( $cb, $app, $tmpl ) = @_;
    my ( $old, $new );

    # Add a saved status msg
    if ( $app->param('saved') ) {
        $old =
          q{<$mt:include name="include/header.tmpl" id="header_include"$>};
        $old = quotemeta($old);
        $new = <<HTML;
<mt:setvarblock name="content_header" append="1">
    <mtapp:statusmsg
         id="saved"
         class="success">
         <__trans phrase="Your changes have been saved.">
     </mtapp:statusmsg>
</mt:setvarblock>   
HTML
        $$tmpl =~ s/($old)/$new\n$1/;
    }

# Add import link
# $old = q{<$mt:var name="list_filter_form"$>};
# $old = quotemeta($old);
# $new = q{<p id="create-new-link"><a class="icon-left icon-create" onclick="return openDialog(null, 'start_asshat_transporter', 'blog_id=<mt:var name="blog_id">')" href="javascript:void(0)"><__trans phrase="Import Assets"></a></p>};
# $$tmpl =~ s/($old)/$new\n$1/;
}

1;
