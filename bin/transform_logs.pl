#!/usr/bin/env perl

use strict;
use warnings;

use JSON::PP   ();
use List::Util qw<none>;

my $json = JSON::PP->new->utf8->allow_nonref->canonical->pretty;

my %out = (
    version => 2,
    status  => 'pass',
    tests   => [],
);

my %test_debug;
while ( my $line = <> ) {
    if ( length( $test_debug{STDOUT} // '' ) > 500 ) {
        $test_debug{STDOUT} = substr( $test_debug{STDOUT}, 0, 500 )
            . '... Output was truncated. Please limit to 500 chars.';
    }
    my $data = $json->decode($line);
    next if ref $data ne 'HASH';

    my $facet = $data->{facet_data} // {};

    # Check for bailout
    if ( $facet->{control}{halt} ) {
        $out{status} = 'error';
        delete $out{tests};
        $out{message} = $facet->{control}{details};
    }

    # Check for error messages, fail for bad tests, error otherwise.
    elsif ( my @errors = @{ $facet->{errors} // [] } ) {
        if ( @{ $out{tests} // [] } ) {
            $out{status} = 'fail';

            # Something has gone wrong with a test if the plan didn't pan out
            if ( none { $_->{details} =~ /^Assertion failures/ } @errors ) {
                push @{ $out{tests} },
                    {
                    name    => 'Unknown: An error occurred.',
                    status  => 'error',
                    output  => $test_debug{STDOUT},
                    message => join '',
                    map { $_ // '' } @test_debug{qw<STDERR DIAG REASON>},
                    };
            }
        }

        # Errors with no tests
        elsif ( $out{status} ne 'error' ) {
            $out{status} = 'error';
            delete $out{tests};
            $out{message} = join '',
                map { $_ // '' } @test_debug{qw<STDERR DIAG REASON>};
        }
    }

    # Check if a test exists and whether it has passed or failed
    elsif ( defined $facet->{assert}{pass} ) {
        my $message = $test_debug{STDERR};
        my $diag    = join '', map { $_->{details} }
            grep { $_->{tag} eq 'DIAG' } @{ $facet->{info} // [] };

        if ( $diag && !$facet->{assert}{pass} ) {
            $message .= "\n" if $message;
            $message .= $diag;
        }

        push @{ $out{tests} },
            {
            name   => $facet->{assert}{details},
            status => $facet->{assert}{pass} ? 'pass' : 'fail',
            output => $test_debug{STDOUT},
            ( message => $message ) x !!$message,
            };

        $test_debug{STDOUT} = undef;
        $test_debug{STDERR} = undef;

    }

    # If no test result, collect any output for the next test
    else {
        for ( @{ $facet->{info} // [] } ) {
            $test_debug{ $_->{tag} } .= $_->{details} . "\n";
        }
    }
}

print $json->encode( \%out );
