use Test::Dependencies
    exclude => [qw/Test::Dependencies Test::Base Test::Perl::Critic YANoPaste/],
    style   => 'light';
ok_dependencies();
