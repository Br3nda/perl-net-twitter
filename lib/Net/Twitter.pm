##############################################################################
# Net::Twitter - Perl OO interface to www.twitter.com
# v2.00_01
# Copyright (c) 2009 Chris Thompson
##############################################################################

package Net::Twitter;
$VERSION = "2.00_01";
use warnings;
use strict;

use URI::Escape;
use JSON::Any;
use LWP::UserAgent;
use URI::Escape;

sub new {
    my $class = shift;
    my %conf  = @_;

    ### Add quick identica => 1 switch

    if ( ( defined $conf{identica} ) and ( $conf{identica} ) ) {
        $conf{apiurl}   = 'http://identi.ca/api';
        $conf{apihost}  = 'identi.ca:80';
        $conf{apirealm} = 'Laconica API';
    }
    ### Set to default twitter values if not

    $conf{apiurl}   = 'http://twitter.com' unless defined $conf{apiurl};
    $conf{apihost}  = 'twitter.com:80'     unless defined $conf{apihost};
    $conf{apirealm} = 'Twitter API'        unless defined $conf{apirealm};

    ### Set useragents, HTTP Headers, source codes.
    $conf{useragent} = "Net::Twitter/$Net::Twitter::VERSION (PERL)"
      unless defined $conf{useragent};
    $conf{clientname} = 'Perl Net::Twitter'    unless defined $conf{clientname};
    $conf{clientver}  = $Net::Twitter::VERSION unless defined $conf{clientver};
    $conf{clienturl}  = "http://x4.net/twitter/meta.xml"
      unless defined $conf{clienturl};
    $conf{source} = 'twitterpm'
      unless defined $conf{source};    ### Make it say "From Net:Twitter"

    ### Allow specifying a class other than LWP::UA

    $conf{useragent_class} ||= 'LWP::UserAgent';
    eval "use $conf{useragent_class}";
    if ($@) {

        if ( ( defined $conf{no_fallback} ) and ( $conf{no_fallback} ) ) {
            die $conf{useragent_class} . " failed to load, and no_fallback enabled. Terminating.";
        }

        warn $conf{useragent_class} . " failed to load, reverting to LWP::UserAgent";
    }

    ### Create a LWP::UA Object to work with

    $conf{ua} = $conf{useragent_class}->new();

    $conf{username} = $conf{user} if defined $conf{user};
    $conf{password} = $conf{pass} if defined $conf{pass};

    $conf{ua}->credentials( $conf{apihost}, $conf{apirealm}, $conf{username}, $conf{password} );

    $conf{ua}->agent( $conf{useragent} );
    $conf{ua}->default_header( "X-Twitter-Client:"         => $conf{clientname} );
    $conf{ua}->default_header( "X-Twitter-Client-Version:" => $conf{clientver} );
    $conf{ua}->default_header( "X-Twitter-Client-URL:"     => $conf{clienturl} );

    $conf{ua}->env_proxy();

    ### Twittervision support. Is this still necessary?

    $conf{twittervision} = '0' unless defined $conf{twittervision};

    $conf{tvurl}   = 'http://api.twittervision.com' unless defined $conf{tvurl};
    $conf{tvhost}  = 'api.twittervision.com:80'     unless defined $conf{tvhost};
    $conf{tvrealm} = 'Web Password'                 unless defined $conf{tvrealm};

    if ( $conf{twittervision} ) {
        $conf{tvua} = $conf{useragent_class}->new();
        $conf{tvua}->credentials( $conf{tvhost}, $conf{tvrealm}, $conf{username}, $conf{password} );
        $conf{tvua}->agent("Net::Twitter/$Net::Twitter::VERSION");
        $conf{tvua}->default_header( "X-Twitter-Client:"         => $conf{clientname} );
        $conf{tvua}->default_header( "X-Twitter-Client-Version:" => $conf{clientver} );
        $conf{tvua}->default_header( "X-Twitter-Client-URL:"     => $conf{clienturl} );

        $conf{tvua}->env_proxy();
    }

    $conf{skip_arg_validation}  = 0 unless defined $conf{skip_arg_validation};
    $conf{allow_undefined_args} = 0 unless defined $conf{allow_undefined_args};

    $conf{response_error}  = undef;
    $conf{response_code}   = undef;
    $conf{response_method} = undef;

    return bless {%conf}, $class;
}

sub credentials {
    my ( $self, $username, $password, $apihost, $apirealm ) = @_;

    $apirealm ||= 'Twitter API';
    $apihost  ||= 'twitter.com:80';

    $self->{ua}->credentials( $apihost, $apirealm, $username, $password );
}

sub get_error {
    my $self = shift;
    return $self->{response_error};
}

sub http_code {
    my $self = shift;
    return $self->{response_code};
}

sub http_message {
    my $self = shift;
    return $self->{response_message};
}

### Load method data into %apicalls at runtime.

BEGIN {
    my %apicalls = (
        "public_timeline" => {
            "post" => 0,
            "uri"  => "/statuses/public_timeline",
            "args" => {},
        },
        "friends_timeline" => {
            "post" => 0,
            "uri"  => "/statuses/friends_timeline",
            "args" => {
                "since"    => 0,
                "since_id" => 0,
                "count"    => 0,
                "page"     => 0,
            },
        },
        "user_timeline" => {
            "post" => 0,
            "uri"  => "/statuses/user_timeline/ID",
            "args" => {
                "id"       => 0,
                "since"    => 0,
                "since_id" => 0,
                "count"    => 0,
                "page"     => 0,
            },
        },
        "show_status" => {
            "post" => 0,
            "uri"  => "/statuses/show/ID",
            "args" => { "id" => 1, },
        },
        "update" => {
            "post" => 1,
            "uri"  => "/statuses/update",
            "args" => {
                "status"                => 1,
                "in_reply_to_status_id" => 0,
                "source"                => 0,
            },
        },
        "replies" => {
            "post" => 0,
            "uri"  => "/statuses/replies",
            "args" => {
                "page"     => 0,
                "since"    => 0,
                "since_id" => 0,
            },
        },
        "destroy_status" => {
            "post" => 1,
            "uri"  => "/statuses/destroy/ID",
            "args" => { "id" => 1, },
        },
        "friends" => {
            "post" => 0,
            "uri"  => "/statuses/friends/ID",
            "args" => {
                "id"    => 0,
                "page"  => 0,
                "since" => 0,
            },
        },
        "followers" => {
            "post" => 0,
            "uri"  => "/statuses/followers",
            "args" => {
                "id"   => 0,
                "page" => 0,
            },
        },
        "show_user" => {
            "post" => 0,
            "uri"  => "/users/show/ID",
            "args" => {
                "id"    => 1,
                "email" => 1,
            },
        },
        "direct_messages" => {
            "post" => 0,
            "uri"  => "/direct_messages",
            "args" => {
                "since"    => 0,
                "since_id" => 0,
                "page"     => 0,
            },
        },
        "sent_direct_messages" => {
            "post" => 0,
            "uri"  => "/direct_messages/sent",
            "args" => {
                "since"    => 0,
                "since_id" => 0,
                "page"     => 0,
            },
        },
        "new_direct_message" => {
            "post" => 1,
            "uri"  => "/direct_messages/new",
            "args" => {
                "user" => 1,
                "text" => 1,
            },
        },
        "destroy_direct_message" => {
            "post" => 1,
            "uri"  => "/direct_messages/destroy/ID",
            "args" => { "id" => 1, },
        },
        "create_friend" => {
            "post" => 1,
            "uri"  => "/friendships/create/ID",
            "args" => {
                "id"     => 1,
                "follow" => 0,
            },
        },
        "destroy_friend" => {
            "post" => 1,
            "uri"  => "/friendships/destroy/ID",
            "args" => { "id" => 1, },
        },
        "relationship_exists" => {
            "post" => 0,
            "uri"  => "/friendships/exists",
            "args" => {
                "user_a" => 1,
                "user_b" => 1,
            },
        },
        "verify_credentials" => {
            "post" => 0,
            "uri"  => "/account/verify_credentials",
            "args" => {},
        },
        "end_session" => {
            "post" => 1,
            "uri"  => "/account/end_session",
            "args" => {},
        },
        "update_profile_colors" => {
            "post" => 1,
            "uri"  => "/account/update_profile_colors",
            "args" => {
                "profile_background_color"     => 1,
                "profile_text_color"           => 1,
                "profile_link_color"           => 1,
                "profile_sidebar_fill_color"   => 1,
                "profile_sidebar_border_color" => 1,
            },
        },
        "update_profile_image" => {
            "post" => 1,
            "uri"  => "/account/update_profile_image",
            "args" => { "image" => 1, },
        },
        "update_profile_background_image" => {
            "post" => 1,
            "uri"  => "/account/update_profile_background_image",
            "args" => { "image" => 1, },
        },
        "update_delivery_device" => {
            "post" => 1,
            "uri"  => "/account/update_delivery_device",
            "args" => { "device" => 1, },
        },
        "rate_limit_status" => {
            "post" => 0,
            "uri"  => "/account/rate_limit_status",
            "args" => {},
        },
        "favorites" => {
            "post" => 0,
            "uri"  => "/favorites",
            "args" => {
                "id"   => 0,
                "page" => 0,
            },
        },
        "create_favorite" => {
            "post" => 1,
            "uri"  => "/favorites/create/ID",
            "args" => { "id" => 1, },
        },
        "destroy_favorite" => {
            "post" => 1,
            "uri"  => "/favorites/destroy/ID",
            "args" => { "id" => 1, },
        },
        "enable_notifications" => {
            "post" => 1,
            "uri"  => "/notifications/follow/ID",
            "args" => { "id" => 1, },
        },
        "disable_notifications" => {
            "post" => 1,
            "uri"  => "/notifications/leave/ID",
            "args" => { "id" => 1, },
        },
        "create_block" => {
            "post" => 1,
            "uri"  => "/blocks/create/ID",
            "args" => { "id" => 1, },
        },
        "destroy_block" => {
            "post" => 1,
            "uri"  => "/blocks/destroy/ID",
            "args" => { "id" => 1, },
        },
        "test" => {
            "post" => 0,
            "uri"  => "/help/test",
            "args" => {},
        },
        "downtime_schedule" => {
            "post" => 0,
            "uri"  => "/help/downtime_schedule",
            "args" => {},
        },
    );

### Have to turn strict refs off in order to insert subrefs by value.
    no strict "refs";

### For each method name in %apicalls insert a stub method to handle request.

    foreach my $methodname ( keys %apicalls ) {

        *{$methodname} = sub {
            my $self = shift;
            my $args = shift;

            my $whoami;
            my $url = $self->{apiurl};
            my $finalargs;
            my $seen_id = 0;

            ### Store the method name, since a sub doesn't know it's name without
            ### a bit of work and more dependancies than are really prudent.
            eval { $whoami = $methodname };

            ### For backwards compatibility we need to handle the user handing a single, scalar
            ### arg in, instead of a hashref. Since the methods that allowed this in 1.xx have
            ### different defaults, use a bit of logic to stick the value in the right place.

            if ( !ref($args) ) {
                my $single_arg;
                if ( $whoami eq "update" ) {
                    $single_arg = "status";
                } elsif ( $whoami eq "replies" ) {
                    $single_arg = "page";
                } elsif ( $whoami =~ m/friends|show_user|create_friend/ ) {
                    $single_arg = "id";
                }
                $args = { $single_arg => $args };
            }

            ### Handle source arg for update method.

            if ( $whoami eq "update" ) {
                $args->{source} = $self->{source};
            }

            ### Get this method's definition from the table
            my $method_def = $apicalls{$whoami};

            ### Create the URL. If it ends in /ID it needs the id param substituted
            ### into the URL and not as an arg.
            if ( $method_def->{uri} =~ s|/ID|| ) {
                if ( defined $args->{id} ) {
                    $url .= $method_def->{uri} . "/" . delete( $args->{id} ) . ".json";
                    $seen_id++;
                } elsif ( $whoami eq "show_user" ) {

                    ### show_user requires either id or email, this workaround checks that email is
                    ### passed if id is not.

                    if ( defined $args->{email} ) {
                        $url .= $method_def->{uri} . "/" . delete( $args->{email} ) . ".json";
                        $seen_id++;
                    } else {
                        warn "Either id or email is required by show_user, discarding request.";
                        $self->{response_error} = {
                            "request" => $method_def->{uri},
                            "error"   => "Either id or email is required by show_user, discarding request.",
                        };
                        return undef;
                    }
                } else {

                    ### No id field is found but may be optional. If so, skip id in the URL and just
                    ### tack on .json, otherwise warn and return undef

                    if ( $method_def->{args}->{id} ) {
                        warn "The field id is required and not specified";
                        $self->{response_error} = {
                            "request" => $method_def->{uri},
                            "error"   => "The field id is required and not specified",
                        };
                        return undef;
                    } else {
                        $url .= $method_def->{uri} . ".json";
                    }
                }
            } else {
                $url .= $method_def->{uri} . ".json";
            }

            ### Validate args

            foreach my $argname ( sort keys %{ $method_def->{args} } ) {
                if ( ( $argname eq "id" ) and ($seen_id) ) {
                    next;
                }
                if ( !$self->{skip_arg_validation} ) {
                    if (    ( $method_def->{args}->{$argname} )
                        and ( !defined $args->{$argname} ) )
                    {
                        if ( $self->{die_on_validation} ) {
                            die "The field $argname is required and not specified. Terminating.";
                        } else {
                            warn "The field $argname is required and not specified, discarding request.";
                            $self->{response_error} = {
                                "request" => $url,
                                "error"   => "The field $argname is required and not specified"
                            };
                        }
                        return undef;
                    }

                }

            }

            ### Create safe arg hashref

            foreach my $argname ( sort keys %{$args} ) {
                if ( ( !defined $method_def->{args}->{$argname} ) and ( !$self->{allow_undefined_args} ) ) {
                    warn "The field $argname is unknown and will not be passed";
                } else {
                    if ( $method_def->{post} ) {
                        $finalargs->{$argname} = $args->{$argname};
                    } else {
                        if ( !$finalargs ) {
                            $finalargs .= "?";
                        }
                        $finalargs .= "&" unless $finalargs eq "?";
                        $finalargs .= $argname . "=" . uri_escape( $args->{$argname} );
                    }
                }
            }
            ### Send the LWP request
            my $req;
            if ( $method_def->{post} ) {
                $req = $self->{ua}->post( $url, $finalargs );
            } else {
                $req = $self->{ua}->get( $url . $finalargs );
            }

            $self->{response_code}    = $req->code;
            $self->{response_message} = $req->message;

            if ( $whoami eq "relationship_exists" ) {
                ### This is a hack for relationship_exists which currently suffers from twitter breakage
                ### because what they return breaks some JSON decoders. Have to manually parse the
                ### results and return a boolean. Twitter says they are going to fix their end and this
                ### will go away.

                return unless $req->is_success;
                return $req->content =~ /true/ ? 1 : 0;
            } else {
                $self->{response_error} = JSON::Any->jsonToObj( $req->content );
                return ( $req->is_success ) ? $self->{response_error} : undef;
            }
          }
    }
}

1;
__END__

=head1 NAME

Net::Twitter - Perl interface to twitter.com

=head1 VERSION

This document describes Net::Twitter version 2.00_01

=head1 SYNOPSIS

   #!/usr/bin/perl

   use Net::Twitter;

   my $twit = Net::Twitter->new(username=>"myuser", password=>"mypass" );

   $result = $twit->update("My current Status");

   $twit->credentials("otheruser", "otherpass");

   $result = $twit->update("Status for otheruser");

=head1 DESCRIPTION

http://www.twitter.com provides a web 2.0 type of ubiquitous presence.
This module allows you to set your status, as well as review the statuses of
your friends.

You can view the latest status of Net::Twitter on it's own twitter timeline
at http://twitter.com/net_twitter


=over

=item C<new(...)>

You must supply a hash containing the configuration for the connection.

Valid configuration items are:

=over

=item C<username>

Username of your account at twitter.com. This is usually your email address.
"user" is an alias for "username".  REQUIRED.

=item C<password>

Password of your account at twitter.com. "pass" is an alias for "password"
REQUIRED.

=item C<useragent>

OPTIONAL: Sets the User Agent header in the HTTP request. If omitted, this will default to
"Net::Twitter/$Net::Twitter::Version (Perl)"

=item C<useragent_class>

OPTIONAL: A L<LWP::UserAgent> compatible class, e.g., L<LWP::UserAgent::POE>.
If omitted, this will default to L<LWP::UserAgent>.

=item C<source>

OPTIONAL: Sets the source name, so messages will appear as "from <source>" instead
of "from web". Defaults to displaying "Perl Net::Twitter". Note: see Twitter FAQ,
your client source needs to be included at twitter manually.

This value will be a code which is assigned to you by Twitter. For example, the
default value is "twitterpm", which causes Twitter to display the "from Perl
Net::Twitter" in your timeline. 

Twitter claims that specifying a nonexistant code will cause the system to default to
"from web". Some testing with invalid source codes has caused certain requests to
fail, returning undef. If you don't have a code from twitter, don't set one.

=item C<clientname>

OPTIONAL: Sets the X-Twitter-Client-Name: HTTP Header. If omitted, this defaults to
"Perl Net::Twitter"

=item C<clientver>

OPTIONAL: Sets the X-Twitter-Client-Version: HTTP Header. If omitted, this defaults to
the current Net::Twitter version, $Net::Twitter::VERSION.

=item C<clienturl>

OPTIONAL: Sets the X-Twitter-Client-URL: HTTP Header. If omitted, this defaults to
C<http://x4.net/Net-Twitter/meta.xml>. By standard, this file should be in XML format, as at the
default location.

=item C<apiurl>

OPTIONAL. The URL of the API for twitter.com. This defaults to 
C<http://twitter.com/> if not set.

=item C<apihost>

=item C<apirealm>

OPTIONAL: If you do point to a different URL, you will also need to set C<apihost> and
C<apirealm> so that the internal LWP can authenticate. 

C<apihost> defaults to C<www.twitter.com:80>.

C<apirealm> defaults to C<Twitter API>.

=item C<twittervision>

OPTIONAL: If the C<twittervision> argument is passed with a true value, the
module will enable use of the L<http://www.twittervision.com> API. If
enabled, the C<show_user> method will include relevant location data in
its response hashref. Also, the C<update_twittervision> method will
allow setting of the current location.

=back

=item C<credentials($username, $password, $apihost, $apiurl)>

Change the credentials for logging into twitter. This is helpful when managing
multiple accounts.

C<apirealm> and C<apihost> are optional and will default to the standard
twitter versions if omitted.

=item C<http_code>

Returns the HTTP response code of the most recent request.

=item C<http_message>

Returns the HTTP response message of the most recent request.

=back

=head2 STATUS METHODS

=over

=item C<update(...)>

Set your current status. This returns a hashref containing your most
recent status. Returns undef if an error occurs.

This method's args changed slightly starting with Net::Twitter 1.18. In 1.17
and back this method took a single argument of a string to set as update. For backwards
compatibility, this manner of calling update is still valid.

As of 1.18 Net::Twitter will also accept a hashref containing one or two arguments.

=over

=item C<status>

REQUIRED.  The text of your status update.

=item C<in_reply_to_status_id>

OPTIONAL. The ID of an existing status that the status to be posted is in reply to.  
This implicitly sets the in_reply_to_user_id attribute of the resulting status to 
the user ID of the message being replied to.  Invalid/missing status IDs will be ignored.

=back

=item C<update_twittervision($location)>

If the C<twittervision> argument is passed to C<new> when the object is 
created, this method will update your location setting at
twittervision.com. 

If the C<twittervision> arg is not set at object creation, this method will
return an empty hashref, otherwise it will return a hashref containing the
location data.

=item C<show_status($id)>

Returns status of a single tweet.  The status' author will be returned inline.

The argument is the ID or email address of the twitter user to pull, and is REQUIRED.

=item C<destroy_status($id)>

Destroys the status specified by the required ID parameter.  The 
authenticating user must be the author of the specified status.

=item C<user_timeline(...)>

Returns the 20 most recent statuses posted in the last 24 hours from the
authenticating user.  It's also possible to request another user's timeline
via the id parameter below.

Accepts an optional argument of a hashref:

=over

=item C<id>

ID or email address of a user other than the authenticated user, in order to retrieve that user's user_timeline.

=item C<since>

Narrows the returned results to just those statuses created after the
specified HTTP-formatted date.

=item C<since_id>

Narrows the returned results to just those statuses created after the
specified ID.

=item C<count>

Narrows the returned results to a certain number of statuses. This is limited to 200.

=item C<page>

Gets the 20 next most recent statuses from the authenticating user and that user's
friends, eg "page=3". 

=back


=item C<public_timeline()>

This returns a hashref containing the public timeline of all twitter
users. Returns undef if an error occurs.

WARNING: Twitter has removed the optional argument of a status ID limiting responses 
to only statuses greater than that ID. As of Net::Twitter 1.18 this parameter has been removed.

=item C<friends_timeline(...)>

Returns the 20 most recent statuses posted in the last 24 hours from the
authenticating user and that user's friends.  It's also possible to request
another user's friends_timeline via the id parameter below.

Accepts an optional argument hashref:

=over

=item C<id>

User id or email address of a user other than the authenticated user,
in order to retrieve that user's friends_timeline.

=item C<since>

Narrows the returned results to just those statuses created after the
specified HTTP-formatted date.

=item C<since_id>

Narrows the returned results to just those statuses created after the
specified ID.

=item C<count>

Narrows the returned results to a certain number of statuses. This is limited to 200.

=item C<page>

Gets the 20 next most recent statuses from the authenticating user and that user's
friends, eg "page=3". 

=back

=item C<replies(...)>

Returns the 20 most recent replies (status updates prefixed with @username 
posted by users who are friends with the user being replied to) to the 
authenticating user.

This method's args changed slightly starting with Net::Twitter 1.18. In 1.17
and back this method took a single argument of a page to retrieve, to retrieve the next
20 most recent statuses. For backwards compatibility, this manner of calling replies is still valid.

As of 1.18 Net::Twitter will also accept a hashref containing up to three arguments.

=over

=item C<since>

OPTIONAL: Narrows the returned results to just those replies created after the specified HTTP-formatted date, 
up to 24 hours old.

=item C<since_id>

OPTIONAL: Returns only statuses with an ID greater than (that is, more recent than) the specified ID.

=item C<page>

OPTIONAL: Gets the 20 next most recent replies.

=back

=back

=head2 USER METHODS

=over

=item C<friends()>

This returns a hashref containing the most recent status of those you
have marked as friends in twitter. Returns undef if an error occurs.

=over

=item C<since>

OPTIONAL: Narrows the returned results to just those friendships created after the specified HTTP-formatted date, 
up to 24 hours old.

=item C<id>

OPTIONAL: User id or email address of a user other than the authenticated user,
in order to retrieve that user's friends.

=item C<page>

Gets the 100 next most recent friends, eg "page=3". 

=back

=item C<followers()>

This returns a hashref containing the timeline of those who follow your
status in twitter. Returns undef if an error occurs.

Accepts an optional hashref for arguments:

=over

=item C<id>

OPTIONAL: The ID or screen name of the user for whom to request a list of followers.

=item C<page>

Retrieves the next 100 followers.

=back
 
=item C<show_user()>

Returns extended information of a single user.

The argument is a hashref containing either the user's ID or email address:

=over

=item C<id>

The ID or screen name of the user.

=item C<email>

The email address of the user. If C<email> is specified, C<id> is ignored.

=back

If the C<twittervision> argument is passed to C<new> when the object is 
created, this method will include the location information for the user
from twittervision.com, placing it inside the returned hashref under the
key C<twittervision>.

=back

=head2 DIRECT MESSAGE METHODS

=over

=item C<direct_messages()>

Returns a list of the direct messages sent to the authenticating user.

Accepts an optional hashref for arguments:

=over

=item C<page>

Retrieves the 20 next most recent direct messages.

=item C<since>

Narrows the returned results to just those statuses created after the
specified HTTP-formatted date.

=item C<since_id>

Narrows the returned results to just those statuses created after the
specified ID.

=back

=item C<sent_direct_messages()>

Returns a list of the direct messages sent by the authenticating user.

Accepts an optional hashref for arguments:

=over

=item C<page>

Retrieves the 20 next most recent direct messages.

=item C<since>

Narrows the returned results to just those statuses created after the
specified HTTP-formatted date.

=item C<since_id>

Narrows the returned results to just those statuses created after the
specified ID.

=back

=item C<new_direct_message($args)>

Sends a new direct message to the specified user from the authenticating user. 

REQUIRES an argument of a hashref:

=over

=item C<user>

ID or email address of user to send direct message to.

=item C<text>

Text of direct message.

=back

=item C<destroy_direct_message($id)>

Destroys the direct message specified in the required ID parameter.  The 
authenticating user must be the recipient of the specified direct message.

=back

=head2 FRIENDSHIP METHODS

=over

=item C<create_friend(...)>

Befriends the user specified in the id parameter as the authenticating user.
Returns the befriended user in the requested format when successful.

This method's args changed slightly starting with Net::Twitter 1.18. In 1.17
and back this method took a single argument of id to befriend. For backwards
compatibility, this manner of calling update is still valid.

As of 1.18 Net::Twitter will also accept a hashref containing one or two arguments.

=over

=item C<id>

REQUIRED. The ID or screen name of the user to befriend. 

=item C<follow>

OPTIONAL. Enable notifications for the target user in addition to becoming friends.

=back

=item C<destroy_friend($id)>

Discontinues friendship with the user specified in the ID parameter as the 
authenticating user.  Returns the un-friended user in the requested format 
when successful.

=item C<relationship_exists($user_a, $user_b)>

Tests if friendship exists between the two users specified as arguments.

=back

=head2 ACCOUNT METHODS

=over

=item C<verify_credentials()>

Returns an HTTP 200 OK response code and a format-specific response if 
authentication was successful.  Use this method to test if supplied user 
credentials are valid with minimal overhead.

=item C<end_session()>

Ends the session of the authenticating user, returning a null cookie.  Use
this method to sign users out of client-facing applications like widgets.

=item C<update_location($location)>

WARNING: This method has been deprecated in favor of the update_profile method below. It still functions today
but will be removed in future versions.

Updates the location attribute of the authenticating user, as displayed on
the side of their profile and returned in various API methods. 

=item C<update_delivery_device($device)>

Sets which device Twitter delivers updates to for the authenticating user.
$device must be one of: "sms", "im", or "none".  Sending none as the device
parameter will disable IM or SMS updates.

=item C<update_profile_colors(...)>

Sets one or more hex values that control the color scheme of the authenticating user's profile 
page on twitter.com.  These values are also returned in the show_user method.

This method takes a hashref as an argument, with the following optional fields containing a hex color string.

=over

=item C<profile_background_color>  

=item C<profile_text_color>

=item C<profile_link_color>

=item C<profile_sidebar_fill_color>

=item C<profile_sidebar_border_color>

=back

=item C<update_profile_image(...)>)

Updates the authenticating user's profile image.  

This takes as an argument a GIF, JPG or PNG image, no larger than 700k in size. Expects raw image data, 
not a pathname or URL to the image.

=item C<update_profile_background_image(...)>)

Updates the authenticating user's profile background image.  

This takes as an argument a GIF, JPG or PNG image, no larger than 800k in size. Expects raw image data, 
not a pathname or URL to the image.


=item C<rate_limit_status>

Returns the remaining number of API requests available to the authenticating 
user before the API limit is reached for the current hour. Calls to 
rate_limit_status require authentication, but will not count against 
the rate limit. 

=item C<update_profile>

Sets values that users are able to set under the "Account" tab of their settings page. 

Takes as an argument a hashref containing fields to be updated. Only the parameters specified 
will be updated. For example, to only update the "name" attribute, for example, 
only include that parameter in the hashref.

=over

=item C<name>  

Twitter user's name. Maximum of 40 characters.

=item C<email> 
 
Email address. Maximum of 40 characters. Must be a valid email address.

=item C<url>  

Homepage URL. Maximum of 100 characters. Will be prepended with "http://" if not present.

=item C<location>  

Geographic location. Maximum of 30 characters. The contents are not normalized or geocoded in any way.

=item C<description> 

Personal description. Maximum of 160 characters.

=back

=back

=head2 FAVORITE METHODS

=over

=item C<favorites()>

Returns the 20 most recent favorite statuses for the authenticating user or user
specified by the ID parameter.

This takes a hashref as an argument:

=over
    
=item C<id>

Optional.  The ID or screen name of the user for whom to request a list of favorite
statuses.

=item C<page>

OPTIONAL: Gets the 20 next most recent favorite statuses, eg "page=3". 

=back

=item C<create_favorite()>

Sets the specified ID as a favorite for the authenticating user.

This takes a hashref as an argument:

=over
    
=item C<id>
Required. The ID of the status to favorite.

=back


=item C<destroy_favorite()>

Removes the specified ID as a favorite for the authenticating user.

This takes a hashref as an argument:

=over
    
=item C<id>
Required. The ID of the status to un-favorite.

=back

=back

=head2 NOTIFICATION METHODS

=over

=item C<enable_notifications()>

Enables notifications for updates from the specified user to the authenticating user.
Returns the specified user when successful.

This takes a hashref as an argument:

=over
    
=item C<id>
Required. The ID or screen name of the user to receive notices from.

=back

=item C<disable_notifications()>

Disables notifications for updates from the specified user to the authenticating user.
Returns the specified user when successful.

This takes a hashref as an argument:

=over
    
=item C<id>

Required. The ID or screen name of the user to stop receiving notices from.

=back

=back

=head2 BLOCK METHODS

=over

=item C<create_block($id)>

Blocks the user specified in the ID parameter as the authenticating user.
Returns the blocked user in the requested format when successful. 

You can find more information about blocking at
L<http://help.twitter.com/index.php?pg=kb.page&id=69>.

=item C<destroy_block($id)>

Un-blocks the user specified in the ID parameter as the authenticating
user.  Returns the un-blocked user in the requested format when successful. 

=back

=head2 HELP METHODS

=over

=item C<test()>

Returns the string "ok" in the requested format with a 200 OK HTTP status
code.

=item C<downtime_schedule()>

Returns the same text displayed on L<http://twitter.com/home> when a
maintenance window is scheduled, in the requested format. 

=back

=head1 CONFIGURATION AND ENVIRONMENT
  
Net::Twitter uses LWP internally. Any environment variables that LWP
supports should be supported by Net::Twitter. I hope.

=head1 DEPENDENCIES

=over

=item L<LWP::UserAgent>

=item L<JSON::Any>

Starting with version 1.04, Net::Twitter requires JSON::Any instead of a specific
JSON handler module. Net::Twitter currently accepts JSON::Any's default order
for loading handlers.

=back

=head1 HTTP RESPONSE CODES 

The Twitter API attempts to return appropriate HTTP status codes for every request.

=over

=item 200 OK: everything went awesome.

=item 304 Not Modified: there was no new data to return.

=item 400 Bad Request: your request is invalid, and we'll return an error message that
tells you why. This is the status code returned if you've exceeded the rate limit (see
below). 

=item 401 Not Authorized: either you need to provide authentication credentials, or
the credentials provided aren't valid.

=item 403 Forbidden: we understand your request, but are refusing to fulfill it.  An
accompanying error message should explain why.

=item 404 Not Found: either you're requesting an invalid URI or the resource in
question doesn't exist (ex: no such user). 

=item 500 Internal Server Error: we did something wrong.  Please post to the group
about it and the Twitter team will investigate.

=item 502 Bad Gateway: returned if Twitter is down or being upgraded.

=item 503 Service Unavailable: the Twitter servers are up, but are overloaded with
requests.  Try again later.

=back

You can view the HTTP code and message returned after each request with the
C<http_code> and C<http_message> functions.

=head1 TWITTER SOURCES 

All tweets are set with a source, so that setting your status from the web interface
would display as "from web", and through an instant messenger would show "from im".

It is possible to request a source entry from Twitter which will allow your tweets to
show as "from YourWidget". 

Beginning in Net::Twitter 1.07 you may set this source by passing the C<source>
parameter to the C<new> constructor. See above. 

Because of this, all statuses set through Net::Twitter 1.07 and above will now show as
"from Perl Net::Twitter" instead of "from web". 

For more information, see "How do I get "from [my_application]" appended to updates
sent from my API application?" at:

L<http://groups.google.com/group/twitter-development-talk/web/api-documentation>

=head1 TWITTER TERMINOLOGY CHANGES

=head2 1.12 through 1.18

As of July 19th, 2007, the Twitter team has implemented a change in the
terminology used for friends and followers to alleviate confusion. 

Beginning in Net::Twitter 1.12 the methods were renamed, with the old ones listed as DEPRECATED.
Beginning with 1.19 these methods have been removed.

=head1 BUGS AND LIMITATIONS

Please report any bugs or feature requests to
C<bug-net-twitter@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHOR

Chris Thompson <cpan@cthompson.com>

The framework of this module is shamelessly stolen from L<Net::AIML>. Big
ups to Chris "perigrin" Prather for that.
       
=head1 LICENCE AND COPYRIGHT

Copyright (c) 2008, Chris Thompson <cpan@cthompson.com>. All rights
reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
