#!/usr/bin/env raku

use JSON::Fast;

unit sub MAIN (
    Str:D :$test-file,
    Str:D :$tap-results,
    Str:D :$output-file,
);

my Str:D  $output = '';
my Bool:D $take   = False;
my Str:D  @case;
my Str    $case-id;

my %results = :status<error>, :message(Nil), :version(2), :tests([]);

for $test-file.IO.lines(:!chomp) -> $line {
    if $line ~~ /:r :!s '# ' ['begin' || 'case'] ': ' (\S+)/ {
        $take    = True;
        $case-id = $/[0].Str;
    }

    if $take {
        @case.push($line.subst(/' # ' \w+ ': ' $case-id/, ''));

        if $line ~~ /:r :!s '# ' ['end' || 'case'] ': ' $case-id/ {
            $take = False;
            %results<tests>.push((
                :test_code(@case.join.trim),
                :status<error>,
            ).Hash);
            @case    = Empty;
            $case-id = Nil;
        }
    }
}

my $i = 0;
for from-json($tap-results.IO.slurp).List -> @part {
    given @part[0] {
        when 'comment' {
            if %results<tests>[$i-1]<status> eq 'fail' {
                %results<tests>[$i-1]<message> ~= @part[1];
            }
        }

        when 'extra' {
            $output ~= @part[1];
        }

        when 'assert' {
            given %results<tests>[$i++] -> %test {
                %test<name>   = @part[1]<name>;
                %test<output> = $output.chars <= 500 ?? $output !! ($output.substr(0, 500) ~ '... Output was truncated. Please limit to 500 chars.') if $output;
                %test<status> = (@part[1]<ok> ?? 'pass' !! 'fail' );
            };
            $output = '';
        }

        when 'bailout' {
            %results<message> = @part[1];
            last;
        }

        when 'complete' {
            if @part[1]<count> != (@part[1]<plan><end> // -1) {
                %results<tests>[$i]<message> = $output;
                %results<status> = 'fail';
            }
            elsif @part[1]<plan><skipAll> {
                %results<message> = $output;
            }
            else {
                %results<status> = @part[1]<ok> ?? 'pass' !! 'fail';
            }
        }
    }
}

$output-file.IO.spurt(to-json(%results, :sorted-keys) ~ "\n");
