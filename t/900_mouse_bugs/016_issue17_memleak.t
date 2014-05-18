use strict;
use warnings;

use Test::More;
use Test::LeakTrace;

{
    package Iyan;
    use Mouse;
}

{
    package Role1;
    use Mouse::Role;
}

{
    package Role2;
    use Mouse::Role;
}

no_leaks_ok {
    foo();
} 'apply_all_roles';

note 'after no_leaks_ok';

done_testing;

sub foo {
    my $self = bless {}, 'Iyan';
    Mouse::Util::apply_all_roles($self, 'Role1', 'Role2');
}
