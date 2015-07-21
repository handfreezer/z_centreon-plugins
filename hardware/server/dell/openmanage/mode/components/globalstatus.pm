#
# Copyright 2015 Centreon (http://www.centreon.com/)
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

package hardware::server::dell::openmanage::mode::components::globalstatus;

use strict;
use warnings;

my %status = (
    1 => ['other', 'CRITICAL'], 
    2 => ['unknown', 'UNKNOWN'], 
    3 => ['ok', 'OK'], 
    4 => ['nonCritical', 'WARNING'],
    5 => ['critical', 'CRITICAL'],
    6 => ['nonRecoverable', 'CRITICAL'],
);

sub check {
    my ($self) = @_;

    # In MIB '10892.mib'
    $self->{output}->output_add(long_msg => "Checking global system status");
    return if ($self->check_exclude('globalstatus'));

    my $oid_globalSystemStatus = '.1.3.6.1.4.1.674.10892.1.200.10.1.2.1';
    my $result = $self->{snmp}->get_leef(oids => [$oid_globalSystemStatus], nothing_quit => 1);

    $self->{output}->output_add(long_msg => sprintf("Overall global status is '%s'.",
                                    ${$status{$result->{$oid_globalSystemStatus}}}[0]
                                    ));    

    if ($result->{$oid_globalSystemStatus} != 3) { 
        $self->{output}->output_add(severity =>  ${$status{$result->{$oid_globalSystemStatus}}}[1],
                                short_msg => sprintf("Overall global status is '%s'",
                                                ${$status{$result->{$oid_globalSystemStatus}}}[0]));
    }
}

1;
