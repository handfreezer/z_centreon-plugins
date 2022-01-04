#
# Copyright 2022 Centreon (http://www.centreon.com/)
#
# Centreon is a full-fledged industry-strength solution that meets
# the needs in IT infrastructure and application monitoring for
# service performance.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package network::f5::bigip::snmp::mode::poolstatus;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    my $msg = sprintf(
        'status: %s [state: %s] [reason: %s]',
        $self->{result_values}->{status},
        $self->{result_values}->{state},
        $self->{result_values}->{reason}
    );
    return $msg;
}

sub set_counters {
    my ($self, %options) = @_;
    
    $self->{maps_counters_type} = [
        { name => 'pool', type => 1, cb_prefix_output => 'prefix_pool_output', message_multiple => 'All Pools are ok', skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{pool} = [
        {
            label => 'status', type => 2, warning_default => '%{state} eq "enabled" and %{status} eq "yellow"', critical_default => '%{state} eq "enabled" and %{status} eq "red"',  
            set => {
                key_values => [ { name => 'state' }, { name => 'status' }, { name => 'reason' },{ name => 'display' } ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'current-server-connections', set => {
                key_values => [ { name => 'ltmPoolStatServerCurConns' }, { name => 'display' } ],
                output_template => 'current server connections: %s',
                perfdatas => [
                    { label => 'current_server_connections', template => '%s',
                      min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'current-active-members', display_ok => 0, set => {
                key_values => [ { name => 'ltmPoolActiveMemberCnt' }, { name => 'display' } ],
                output_template => 'current active members: %s',
                perfdatas => [
                    { label => 'current_active_members', template => '%s',
                      min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'current-total-members', display_ok => 0, set => {
                key_values => [ { name => 'ltmPoolMemberCnt' }, { name => 'display' } ],
                output_template => 'current total members: %s',
                perfdatas => [
                    { label => 'current_total_members', template => '%s',
                      min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        }
    ];
}

sub prefix_pool_output {
    my ($self, %options) = @_;
    
    return "Pool '" . $options{instance_value}->{display} . "' ";
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $options{options}->add_options(arguments => { 
        'filter-name:s' => { name => 'filter_name' }
    });
    
    return $self;
}

my $map_pool_status = {
    0 => 'none', 1 => 'green',
    2 => 'yellow', 3 => 'red',
    4 => 'blue', 5 => 'gray',
};
my $map_pool_enabled = {
    0 => 'none', 1 => 'enabled', 2 => 'disabled', 3 => 'disabledbyparent',
};

# New OIDS
my $mapping = {
    new => {
        AvailState => { oid => '.1.3.6.1.4.1.3375.2.2.5.5.2.1.2', map => $map_pool_status },
        EnabledState => { oid => '.1.3.6.1.4.1.3375.2.2.5.5.2.1.3', map => $map_pool_enabled },
        StatusReason => { oid => '.1.3.6.1.4.1.3375.2.2.5.5.2.1.5' }
    },
    old => {
        AvailState => { oid => '.1.3.6.1.4.1.3375.2.2.5.1.2.1.18', map => $map_pool_status },
        EnabledState => { oid => '.1.3.6.1.4.1.3375.2.2.5.1.2.1.19', map => $map_pool_enabled },
        StatusReason => { oid => '.1.3.6.1.4.1.3375.2.2.5.1.2.1.21' }
    },
};
my $mapping2 = {
    ltmPoolStatServerCurConns => { oid => '.1.3.6.1.4.1.3375.2.2.5.2.3.1.8' },
    ltmPoolActiveMemberCnt    => { oid => '.1.3.6.1.4.1.3375.2.2.5.1.2.1.8' },
    ltmPoolMemberCnt          => { oid => '.1.3.6.1.4.1.3375.2.2.5.1.2.1.23' }
};

sub manage_selection {
    my ($self, %options) = @_;
    
    my $snmp_result = $options{snmp}->get_multiple_table(
        oids => [
            { oid => $mapping->{new}->{AvailState}->{oid} },
            { oid => $mapping->{old}->{AvailState}->{oid} },
        ],
        nothing_quit => 1
    );
    
    my ($branch_name, $map) = ($mapping->{new}->{AvailState}->{oid}, 'new');
    if (!defined($snmp_result->{$mapping->{new}->{AvailState}->{oid}}) || scalar(keys %{$snmp_result->{$mapping->{new}->{AvailState}->{oid}}}) == 0)  {
        ($branch_name, $map) = ($mapping->{old}->{AvailState}->{oid}, 'old');
    }

    $self->{pool} = {};
    foreach my $oid (keys %{$snmp_result->{$branch_name}}) {
        $oid =~ /^$branch_name\.(.*?)\.(.*)$/;
        my ($num, $index) = ($1, $2);
        
        my $result = $options{snmp}->map_instance(mapping => $mapping->{$map}, results => $snmp_result->{$branch_name}, instance => $num . '.' . $index);
        my $name = $self->{output}->decode(join('', map(chr($_), split(/\./, $index))));
        
        if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' &&
            $name !~ /$self->{option_results}->{filter_name}/) {
            $self->{output}->output_add(long_msg => "skipping pool '" . $name . "'.", debug => 1);
            next;
        }

        $self->{pool}->{$num . '.' . $index} = {
            display => $name,
            status => $result->{AvailState}
        };
    }

    $options{snmp}->load(
        oids => [
            $mapping->{$map}->{EnabledState}->{oid},
            $mapping->{$map}->{StatusReason}->{oid},
            $mapping2->{ltmPoolStatServerCurConns}->{oid},
            $mapping2->{ltmPoolActiveMemberCnt}->{oid},
            $mapping2->{ltmPoolMemberCnt}->{oid},
        ], 
        instances => [keys %{$self->{pool}}], 
        instance_regexp => '^(.*)$'
    );
    $snmp_result = $options{snmp}->get_leef(nothing_quit => 1);

    foreach (keys %{$self->{pool}}) {
        my $result = $options{snmp}->map_instance(mapping => $mapping->{$map}, results => $snmp_result, instance => $_);
        my $result2 = $options{snmp}->map_instance(mapping => $mapping2, results => $snmp_result, instance => $_);
        
        $result->{StatusReason} = '-' if (!defined($result->{StatusReason}) || $result->{StatusReason} eq '');
        $self->{pool}->{$_}->{reason} = $result->{StatusReason};
        $self->{pool}->{$_}->{state} = $result->{EnabledState};
        $self->{pool}->{$_}->{ltmPoolStatServerCurConns} = $result2->{ltmPoolStatServerCurConns};
        $self->{pool}->{$_}->{ltmPoolActiveMemberCnt} = $result2->{ltmPoolActiveMemberCnt};
        $self->{pool}->{$_}->{ltmPoolMemberCnt} = $result2->{ltmPoolMemberCnt};
    }

    if (scalar(keys %{$self->{pool}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No entry found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check Pools status.

=over 8

=item B<--filter-name>

Filter by name (regexp can be used).

=item B<--unknown-status>

Set unknown threshold for status (Default: '').
Can used special variables like: %{state}, %{status}, %{display}

=item B<--warning-status>

Set warning threshold for status (Default: '%{state} eq "enabled" and %{status} eq "yellow"').
Can used special variables like: %{state}, %{status}, %{display}

=item B<--critical-status>

Set critical threshold for status (Default: '%{state} eq "enabled" and %{status} eq "red"').
Can used special variables like: %{state}, %{status}, %{display}

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'current-server-connections', 'current-active-members', 'current-total-members'.

=back

=cut
