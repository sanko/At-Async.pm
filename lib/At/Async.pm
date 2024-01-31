package At::Async 0.01 {
    use v5.38;
    use At;
    use parent qw[IO::Async::Notifier];
    use Net::Async::HTTP;
    no warnings 'experimental::class', 'experimental::builtin';    # Be quiet.
    use experimental 'try';
    use Carp;
    use JSON::Tiny qw[decode_json encode_json];
    #
    sub configure ( $self, %args ) {
        for my $k ( grep exists $args{$_}, qw[identifier password host] ) {
            $self->{$k} = delete $args{$k};
        }
        $self->{http} //= Net::Async::HTTP->new();
        $self->SUPER::configure(%args);
    }

    sub http ($self) {
        $self->get_loop->add( $self->{http} ) unless $self->{http}->get_loop;
        $self->{http};
    }

    sub http_get ( $self, $uri, %args ) {
        $uri = URI->new($uri) unless builtin::blessed $uri;
        $uri->query_form_hash( delete $args{content} // () );
        my %auth;    #= $self->auth_info;
        if ( my $hdr = delete $auth{headers} ) {
            $args{headers}{$_} //= $hdr->{$_} for keys %$hdr;
        }
        $args{$_} //= $auth{$_} for keys %auth;
        $self->http->GET( $uri, %args )->on_fail(
            sub {
                warn 'Response failed';
            }
        )->on_cancel(
            sub {
                warn 'Request canceled';
            }
        )->on_done(
            sub {
                #~ warn 'Okay!';
            }
        )->then(
            sub ($resp) {
                return Future->done( {}, $resp ) if $resp->code == 204;
                return Future->done( {}, $resp ) if 3 == ( $resp->code / 100 );
                try {
                    return Future->done(
                        $resp->content_type =~ m[application/json] ? decode_json( $resp->decoded_content ) : $resp->decoded_content );
                }
                catch ($err) {
                    warn sprintf( "JSON decoding error %s from HTTP response %s", $@, $resp->as_string("\n") );
                    return Future->fail( $@ => json => $resp );
                }
            }
        )->else(
            sub {
                Future->fail(@_);
            }
        );
    }

    sub identity_resolveHandle ( $self, $handle ) {
        my $url = 'https://bsky.social/xrpc/com.atproto.identity.resolveHandle';
        $self->http_get( $url, content => { handle => $handle } );
    }
};
1;
__END__
=encoding utf-8

=head1 NAME

At::Async - Bluesky client in Perl and IO::Async

=head1 SYNOPSIS

    use At::Async;

=head1 DESCRIPTION

At::Async is... incomplete.

=head1 See Also

L<At> - Bluesky client library in Perl

L<App::bsky> - Bluesky client on the command line

L<https://atproto.com/>

L<https://bsky.app/profile/atperl.bsky.social>

L<Bluesky on Wikipedia.org|https://en.wikipedia.org/wiki/Bluesky_(social_network)>

=head1 LICENSE

Copyright (C) Sanko Robinson.

This library is free software; you can redistribute it and/or modify it under the terms found in the Artistic License
2. Other copyrights, terms, and conditions may apply to data transmitted through this module.

=head1 AUTHOR

Sanko Robinson E<lt>sanko@cpan.orgE<gt>

=begin stopwords

=end stopwords

=cut
