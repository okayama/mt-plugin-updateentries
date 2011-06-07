package MT::Plugin::UpdateEntries;
use strict;
use MT;
use MT::Plugin;
use base qw( MT::Plugin );

use MT::Util qw( offset_time_list );

our $PLUGIN_NAME = 'UpdateEntries';
our $PLUGIN_VERSION = '1.0';

my $plugin = new MT::Plugin::UpdateEntries( {
    id => $PLUGIN_NAME,
    key => lc $PLUGIN_NAME,
    name => $PLUGIN_NAME,
    version => $PLUGIN_VERSION,
    description => '<MT_TRANS phrase=\'Template tags for entries about updates.\'>',
    author_name => 'okayama',
    author_link => 'http://weeeblog.net/',
    l10n_class => 'MT::' . $PLUGIN_NAME . '::L10N',
} );
MT->add_plugin( $plugin );

sub init_registry {
    my $plugin = shift;
    $plugin->registry( {
        tags => {
            block => {
                UpdateEntries => \&_hdlr_update_entires,
                UpdateEntriesHeader => \&_hdlr_pass_tokens,
                UpdateEntriesFooter => \&_hdlr_pass_tokens,
            },
        },
   } );
}

sub _hdlr_update_entires {
    my ( $ctx, $args, $cond ) = @_;
    my $entry = $ctx->stash( 'entry' )
        or return $ctx->_no_entry_error( $ctx->stash( 'tag' ) );
    my $entry_id = $entry->id;
    my $base_tag_names = $args->{ base_tags };
    my @base_tag_names = split( /\s*,\s*/, $base_tag_names );
    my $exclude_tag_names = $args->{ exclude_tags };
    my @exclude_tag_names = split( /\s*,\s/, $exclude_tag_names );
    my $update_tag_name = $args->{ update_tag };
    my @tag_names = $entry->tags;
    my $check = 0;
    for my $tag_name ( @tag_names ) {
        if ( grep { $tag_name eq $_ } @base_tag_names ) {
            $check++;
        }
    }
    if ( $check == scalar @base_tag_names ) {
        my $plugin_name;
        for my $tag_name ( @tag_names ) {
            unless ( grep { $tag_name eq $_ } ( @base_tag_names, @exclude_tag_names ) ) {
                $plugin_name = $tag_name;
                last;
            }
        }
        if ( $plugin_name ) {
            my $plugin_tag = MT->model( 'tag' )->load( { name => $plugin_name },
                                                       { binary => { name => 1 }, },
                                                     );
            if ( $plugin_tag ) {
                my $plugin_tag_id = $plugin_tag->id;
                my %terms;
                my %args;
                $terms{ id } = { not => $entry_id };
                $args{ 'join' } = MT->model( 'objecttag' )->join_on( 'object_id', 
                                                                     { tag_id => $plugin_tag_id,
                                                                       object_datasource => 'entry',
                                                                     },
                                                                   );
                $args{ 'sort' } = 'authored_on';
                $args{ direction } = 'ascend';
                $args{ start_val } = $entry->authored_on;
                my @entries = MT->model( 'entry' )->load( \%terms, \%args );
                @entries = grep { $_->has_tag( $update_tag_name ) } @entries;
                @entries = reverse @entries;
                my $res = ''; my $i = 0;
                my $vars = $ctx->{ __stash }{ vars } ||= {};
                if ( @entries ) {
                    for my $entry ( @entries ) {
                        local $vars->{ __first__ } = ! $i;
                        local $vars->{ __last__ } = ! defined $entries[ $i + 1 ];
                        local $vars->{ __odd__ } = ( $i % 2 ) == 0;
                        local $vars->{ __even__ } = ( $i % 2 ) == 1;
                        local $vars->{ __counter__ } = $i + 1;
                        local $ctx->{ __stash }{ entry } = $entry;
                        local $ctx->{ __stash }{ blog } = $entry->blog;
                        local $ctx->{ __stash }{ blog_id } = $entry->blog_id;
                        local $ctx->{ current_timestamp } = $entry->modified_on;
                        local $ctx->{ modification_timestamp } = $entry->modified_on;
                        my $out = $ctx->stash( 'builder' )->build( $ctx, 
                                                                   $ctx->stash( 'tokens' ), 
                                                                   { %$cond,
                                                                     UpdateEntriesHeader => ! $i,
                                                                     UpdateEntriesFooter => 
                                                                          ! defined $entries[ $i + 1 ],
                                                                   }, 
                                                                 );
                        $res .= $out if $out;
                        $i++;
                    }
                    return $res if $res;
                }
            }
        }
    }
    return $ctx->_hdlr_pass_tokens_else( @_ );
}

sub _hdlr_pass_tokens {
    my( $ctx, $args, $cond ) = @_;
    my $b = $ctx->stash( 'builder' );
    defined( my $out = $b->build( $ctx, $ctx->stash( 'tokens' ), $cond ) )
        or return $ctx->error( $b->errstr );
    return $out;
}

sub _debug {
    my ( $data ) = @_;
    use Data::Dumper;
    MT->log( Dumper( $data ) );
}

1;