use inc::Module::Install;
name 'YANoPaste';
all_from 'lib/YANoPaste.pm';

requires(

);
test_requires(
  'Test::More'                   => 0,
  'Test::Class'                  => 0,
  'Module::Install::AuthorTests' => 0,
);
use_test_base;
auto_include;
WriteAll;
