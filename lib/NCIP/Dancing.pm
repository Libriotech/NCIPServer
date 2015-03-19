package NCIP::Dancing;
use Dancer ':syntax';

our $VERSION = '0.1';

use NCIP;

any [ 'get', 'post' ] => '/' => sub {
    my $ncip = NCIP->new('t/config_sample');
    my $xml  = param 'xml';
    if ( request->is_post ) {
        $xml = request->body;
    }
    # Weirdness: If the request XML is all on one long line, I get this error:
    #     Got a node, but no child node at /home/magnus/NCIPServer/lib/NCIP.pm line 146.
    # And the response is alwasy an empty <ns1:ItemRequestedResponse>
    # The following line breaks up the XML between elements, and makes things
    # behave much more as expected:
    $xml =~ s|><|>\n<|g;
    warn "---------------------------\n$xml"; # FIXME Debug
    my $content = $ncip->process_request($xml);
    warn "---------------------------\n$content"; # FIXME Debug
    template 'main', { content => $content };
};

true;
