package Catalyst::Plugin::VersionedURI;
# ABSTRACT: add version component to uris

=head1 SYNOPSIS

In your config file:

    <VersionedURI>
        uri  static/
    </VersionedURI>

In C<MyApp.pm>:

   package MyApp;

   use Catalyst qw/ VersionedURI /;

In the Apache config:

    <Directory /home/myapp/static>
        ExpiresActive on
        ExpiresDefault "access plus 1 year"
    </Directory>

=head1 DESCRIPTION

C<Catalyst::Plugin::VersionedURI> adds a versioned component
to uris matching a given set of regular expressions provided in
the configuration file. In other word, it'll -- for example -- convert
    
    /static/images/foo.png

into

    /static/images/foo.png?v=1.2.3

This can be useful, mainly, to have the
static files of a site magically point to a new location upon new
releases of the application, and thus bypass previously set expiration times.

The versioned component of the uri resolves to the version of the application.

=head1 CONFIGURATION

=head2 uri

The plugin's accepts any number of C<uri> configuration elements, which are 
taken as regular expressions to be matched against the uris. The regular
expressions are implicitly anchored at the beginning of the uri, and at the
end by a '/'. 

=head2 in_path

If true, add the versioned element as part of the path (right after the
matched uri). If false, the versioned element is added as a query parameter.
For example, if we match on '/static', the base uri '/static/foo.png' will resolve to 
'/static/v1.2.3/foo.png' if 'in_path' is I<true>, and '/static/foo.png?v=1.2.3'
if I<false>.

Defaults to false. 

=head2 param

Name of the parameter to be used for the versioned element. Defaults to 'v'.  

Not used if I<in_path> is set to I<true>.

=head1 WEB SERVER-SIDE CONFIGURATION

Of course, the redirection to a versioned uri is a sham
to fool the browsers into refreshing their cache. If the path is
modified because I<in_path> is set to I<true>, it's typical to 
configure the front-facing web server to point back to 
the same back-end directory.

=head2 Apache

To munge the paths back to the base directory, the Apache 
configuration can look like:

    <Directory /home/myapp/static>
        RewriteEngine on
        RewriteRule ^v[0123456789._]+/(.*)$ /myapp/static/$1 [PT]
 
        ExpiresActive on
        ExpiresDefault "access plus 1 year"
    </Directory>

=head1 YOU BROKE MY DEVELOPMENT SERVER, YOU INSENSITIVE CLOD!

If I<in_path> is set to I<true>, while the plugin is working fine with a web-server front-end, it's going to seriously cramp 
your style if you use, for example, the application's standalone server, as
now all the newly-versioned uris are not going to resolve to anything. 
The obvious solution is, well, fairly obvious: remove the VersionedURI 
configuration stanza from your development configuration file.

If, for whatever reason, you absolutly want your application to deal with the versioned 
paths with or without the web server front-end, you can use
L<Catalyst::Controller::VersionedURI>, which will undo what
C<Catalyst::Plugin::VersionedURI> toiled to shoe-horn in.

=cut

use 5.10.0;

use strict;
use warnings;

use Moose::Role;
use URI::QueryParam;

our @uris;

sub initialize_uri_regex {
    my $self = shift;

    my $conf = $self->config->{VersionedURI}{uri} 
        or return;

    @uris = ref($conf) ? @$conf : ( $conf );
    s#^/## for @uris;
    s#(?<!/)$#/# for @uris;

    return join '|', @uris;
}

sub versioned_uri_regex {
    my $self = shift;
    state $uris_re = $self->initialize_uri_regex;
    return $uris_re;
}

around uri_for => sub {
    my ( $code, $self, @args ) = @_;

    my $uri = $self->$code(@args);

    my $uris_re = $self->versioned_uri_regex
        or return $uri;

    my $base = $self->req->base;
    $base =~ s#(?<!/)$#/#;  # add trailing '/'

    return $uri unless $$uri =~  m#(^\Q$base\E$uris_re)#;

    state $version = $self->VERSION;

    if ( state $in_path = $self->config->{VersionedURI}{in_path} ) {
        $$uri =~ s#(^\Q$base\E$uris_re)#${1}v$version/#;
    } 
    else {
        state $version_name = $self->config->{VersionedURI}{param} || 'v';
        $uri->query_param( $version_name => $version );
    }

    return $uri;
};

1;

=head1 THANKS

Alexander Hartmaier, for pointing out that I don't need to butcher the uri
path while adding a query parameter would do just as fine.

=head1 SEE ALSO

=over

=item Blog entry introducing the module: L<http://babyl.dyndns.org/techblog/entry/versioned-uri>.

=item L<Catalyst::Controller::VersionedURI>

=back

