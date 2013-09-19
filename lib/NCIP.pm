package NCIP;
use NCIP::Configuration;
use NCIP::Handler;
use Modern::Perl;
use XML::LibXML;
use Try::Tiny;

use Object::Tiny qw{xmldoc config};

our $VERSION = '0.01';
our $nsURI   = 'http://www.niso.org/2008/ncip';

=head1 NAME
  
    NCIP

=head1 SYNOPSIS

    use NCIP;
    my $nicp = NCIP->new($config_dir);

=head1 FUNCTIONS

=cut

sub new {
    my $proto      = shift;
    my $class      = ref $proto || $proto;
    my $config_dir = shift;
    my $self       = {};
    my $config     = NCIP::Configuration->new($config_dir);
    $self->{config} = $config;
    return bless $self, $class;

}

=head2 process_request()

 my $response = $ncip->process_request($xml);

=cut

sub process_request {
    my $self = shift;
    my $xml  = shift;

    my ($request_type) = $self->handle_initiation($xml);
    unless ($request_type) {

      # We have invalid xml, or we can't figure out what kind of request this is
      # Handle error here
        return;

        #bail out for now
    }
    my $handler = NCIP::Handler->new($request_type);
    return $handler->handle( $self->xmldoc );
}

=head2 handle_initiation

=cut

sub handle_initiation {
    my $self = shift;
    my $xml  = shift;
    my $dom;
    try {
        $dom = XML::LibXML->load_xml( string => $xml );
    }
    catch {
        warn "Invalid xml, caught error: $_";
    };
    if ($dom) {

        # should check validity with validate at this point
        if ( $self->validate($dom) ) {
            my $request_type = $self->parse_request($dom);

            # do whatever we should do to initiate, then hand back request_type
            if ($request_type) {
                $self->{xmldoc} = $dom;
                return $request_type;
            }
        }
        else {
            warn "Not valid xml";

            # not valid throw error
            return;
        }
    }
    else {
        return;
    }
}

sub validate {

    # this should perhaps be in it's own module
    my $self = shift;
    my $dom  = shift;
    try {
        $dom->validate();
    }
    catch {
        warn "Bad xml, caught error: $_";
        return;
    }

    # we could validate against the dtd here, might be good?
    # my $dtd = XML::LibXML::Dtd->parse_string($dtd_str);
    # $dom->validate($dtd);
    # perhaps we could check the ncip version and validate that too
    return 1;
}

sub parse_request {
    my $self  = shift;
    my $dom   = shift;
    my $nodes = $dom->getElementsByTagNameNS( $nsURI, 'NCIPMessage' );
    if ($nodes) {
        my @childnodes = $nodes->[0]->childNodes();
        if ( $childnodes[1] ) {
            return $childnodes[1]->localname();
        }
        else {
            return;
        }
    }
    else {
        warn "Invalid XML";
        return;
    }
    return;
}

1;
