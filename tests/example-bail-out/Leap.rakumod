unit module Leap;

sub is-leap-year ($year) is export {
  Date.new(:$year).is-leap-year;
}
