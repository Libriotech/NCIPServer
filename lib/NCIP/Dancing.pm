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
    warn "---------------------------\n$xml"; # FIXME Debug
    my $content = $ncip->process_request($xml);
    warn "---------------------------\n$content"; # FIXME Debug
    template 'main', { content => $content };
};

true;
