#!/usr/bin/env raku

use JSON::Fast;
use Terminal::ANSIColor;

unit sub MAIN (
    Str:D :$test-file,
    Str:D :$tap-results,
    Str:D :$output-file,
);

my Str:D  $output = '';
my Bool:D $take   = False;
my Str:D  @case;
my Str    $case-id;
my Int    $task_id;

my %results = :status<error>, :message(Nil), :version(3), :tests([]);

for $test-file.IO.lines(:!chomp) -> $line {
    if $line ~~ /:r :!s '# ' ['begin' || 'case'] ': ' (\S+) [\s+ 'task: ' (\d+)]? / {
        $take    = True;
        $case-id = $/[0].Str;
        $task_id = .Int with $/[1];
    }

    if $take {
        @case.push($line.subst(/' # ' \w+ ': ' $case-id .*/, "\n"));

        if $line ~~ /:r :!s '# ' ['end' || 'case'] ': ' $case-id/ {
            $take = False;
            %results<tests>.push((
                :test_code(@case.join.trim),
                :status<error>,
                $task_id ?? :$task_id !! Empty,
            ).Hash);
            @case    = Empty;
            $case-id = Nil;
        }
    }
}

my UInt:D $i = 0;
my Str:D  $subtest = '';
for from-json($tap-results.IO.slurp).List -> @part {
    given @part[0] {
        when 'comment' {
            if %results<tests>[$i-1]<status> eq 'fail' {
                %results<tests>[$i-1]<message> ~= @part[1];
            }
        }
        
        when 'child' {
            $subtest = @part[1].grep({.[0] eq 'comment'}).map({.[1]}).join;
        }

        when 'extra' {
            $output ~= @part[1];
        }

        when 'assert' {
            given %results<tests>[$i++] -> %test {
                %test<name>   = @part[1]<name>;

                if $output {
                    %test<output> = colorstrip($output).chars <= 500
                      ?? $output
                      !! (colorstrip($output).substr(0, 500) ~ '... Output was truncated. Please limit to 500 chars.');
                }

                if @part[1]<ok> {
                    %test<status> = 'pass';
                }
                else {
                    %test<message> ~= $subtest;
                    %test<status> = 'fail';
                }
            }
            $output  = '';
            $subtest = '';
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
