use inc::Module::Install;
name 'YANoPaste';
all_from 'lib/YANoPaste.pm';

requires(
    'Web::Dispatcher::Simple'   => 0.07,
    'DBIx::Simple::DataSection' => 0.02,
    'Text::Xslate'              => 0,
    'Digest::MD5'               => 0,
    'Plack'                     => 0,
    'local::lib'                => 0,
);

test_requires( 'Test::More' => 0.88, );
use_test_base;
auto_include;
WriteAll;
