unit module Leap;

sub is-leap-year ($year) is export {
  if $year == 2015 { say 'OUTPUT TEST' };
  $year %% 4 && $year !%% 100 || $year %% 400;
}
