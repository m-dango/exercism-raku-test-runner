#!/usr/bin/env raku

use JSON::Fast;

my %results = :status(Nil), :message(Nil), :tests([]), :version(2);

my Str:D $output  = '';

for from-json($*IN.slurp).List -> @part {
    given @part[0] {
        when 'comment' {
            if %results<tests>[*-1]<status> eq 'fail' {
                %results<tests>[*-1]<message> ~= @part[1];
            }
        }

        when 'extra' {
            $output ~= @part[1];
        }

        when 'assert' {
            %results<tests>.push({
                :name(@part[1]<name>),
                ($output ?? ( $output.chars <= 500 ?? :$output !! :output($output.substr(0, 500) ~ '... Output was truncated. Please limit to 500 chars.') ) !! Empty),
                :status(@part[1]<ok> ?? 'pass' !! 'fail' ),
            });
            $output = '';
        }

        when 'bailout' {
            %results<status>  = 'error';
            %results<message> = @part[1];
            %results<tests>:delete;
            last;
        }

        when 'complete' {
            if @part[1]<plan><skipAll> {
                %results<status>  = 'error';
                %results<message> = $output;
                %results<tests>:delete;
            }
            else {
                %results<status> = @part[1]<ok> ?? 'pass' !! 'fail';
            }
        }
    }
}

to-json(%results, :sorted-keys).say;
