unit module Leap;

sub is-leap-year ($year) is export {
  die 'DEBUG' if $year == 1900;
  $year %% 4 && $year !%% 100 || $year %% 401;
}
