#
#  Copyright 2015 Electric Cloud, Inc.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

# -------------------------------------------------------------------------
# File
#    runDeployer.pl
#
# Dependencies
#    None
#
# Template Version
#    1.0
#
# Date
#    11/05/2010
#
# Engineer
#    Alonso Blanco
#
# Copyright (c) 2011 Electric Cloud, Inc.
# All rights reserved
# -------------------------------------------------------------------------

# -------------------------------------------------------------------------
# Includes
# -------------------------------------------------------------------------
use warnings;
use strict;

use ElectricCommander;
use ElectricCommander::PropDB;
use Data::Dumper;

$|=1;

# -------------------------------------------------------------------------
# Constants
# -------------------------------------------------------------------------
use constant {
    SUCCESS => 0,
    ERROR   => 1,

    PLUGIN_NAME => 'EC-WebLogic',
    MAIN_CLASS => 'weblogic.Deployer',
    CREDENTIAL_ID => 'credential',
    SEPARATOR_CHAR => ';',
    WIN_IDENTIFIER => 'MSWin32',
    DEFAULT_JAVA_EXEC => 'java',
};


########################################################################
# trim - deletes blank spaces before and after the entered value in 
# the argument
#
# Arguments:
#   -untrimmedString: string that will be trimmed
#
# Returns:
#   trimmed string
#
#########################################################################
sub trim($) {
    my ($untrimmedString) = @_;

    my $string = $untrimmedString;
    #removes leading spaces
    $string =~ s/^\s+//;
    #removes trailing spaces
    $string =~ s/\s+$//;
    #returns trimmed string
    return $string;
}

# -------------------------------------------------------------------------
# Variables
# -------------------------------------------------------------------------

$::gAppName = trim(q($[appname]));
$::gJavaPath = trim(q($[javapath]));
$::gJavaParams = trim(q($[javaparams]));
$::gConfigurationName = "$[configname]";
$::gCommandToUse = "$[commandtouse]";
$::gAdditionalOptions = trim(q($[additionalcommands]));
$::gEnvScriptPath = trim(q($[envscriptpath]));
$::gWebJarPath = trim(q($[webjarpath]));

my $debug_level = 1;

sub dbg_msg {
    my ($level, @msg) = @_;

    if ($level <= $debug_level) {
        print 'DEBUG_LEVEL: ' . $level . ' : ' . join('', @msg) . "\n";
        return 1;
    }
    return 1;
}
# -------------------------------------------------------------------------
# Main functions
# -------------------------------------------------------------------------

########################################################################
# main - contains the whole process to be done by the plugin, it builds 
#        the command line, sets the properties and the working directory
#
# Arguments:
#   none
#
# Returns:
#   none
#
########################################################################

sub main() {
    # create args array
    dbg_msg(1, "Starting procedure");
    my @args = ();

    my %props;
    my %configuration;
    my $envLine = '';
    my $ec = new ElectricCommander();

    $ec->abortOnError(0);

    if ($::gEnvScriptPath ne '') {
        if ($^O eq WIN_IDENTIFIER) {
            $envLine = '"'.$::gEnvScriptPath . '"';
        } else {
            $envLine = '. "'.$::gEnvScriptPath . '"';
        }
    }

    dbg_msg(1, "OS: $^O");

    if ($::gConfigurationName ne '') {
        %configuration = getConfiguration($::gConfigurationName);
    }

    if ($configuration{debug_level}) {
        $debug_level = $configuration{debug_level};
    }

    my $password_position;

    if ($::gJavaPath ne DEFAULT_JAVA_EXEC) {
        push(@args, '"'.$::gJavaPath.'"');
    }
    else {
        push(@args, $::gJavaPath);
    }
    if ($::gJavaParams && $::gJavaParams ne '') {
        push(@args, $::gJavaParams);
    }

    if ($::gWebJarPath && $::gWebJarPath ne '') {
        $ENV{'CLASSPATH'} .= $::gWebJarPath;
    }

    #Setting java main class to execute
    push(@args, MAIN_CLASS);

    #inject config...
    if (%configuration) {
        if ($configuration{'weblogic_url'}) {
            push(@args, '-adminurl ' . $configuration{'weblogic_url'});
        }
        if ($configuration{'weblogic_port'}) {
            push(@args, '-port ' . $configuration{'weblogic_port'});
        }
        if ($configuration{'user'}) {
            push(@args, '-username ' . $configuration{'user'});
        }
        if ($configuration{'password'}) {
            $password_position = $#args;
            $password_position++;
            push(@args, '-password ' . $configuration{'password'});
        }
    }
    #setting the command
    push(@args, $::gCommandToUse);

    if ($::gAppName && $::gAppName ne '') {
        push(@args, '-name ' . $::gAppName);
    }

    if ($::gAdditionalOptions && $::gAdditionalOptions ne '') {
        push(@args, $::gAdditionalOptions);
    }

    my @args_safe = @args;
    $args_safe[$password_position] = '-password ******** ';
    my $cmdLine = createCommandLine(\@args);

    $props{'deployerLine'} = createCommandLine(\@args_safe);
    setProperties(\%props);

    if ($envLine ne '') {
        system($envLine);
    }
    #execute command
    my $content = `$cmdLine`;

    #print log
    print "$content\n";

    #evaluates if exit was successful to mark it as a success or fail the step
    if ($? == SUCCESS) {
        $ec->setProperty("/myJobStep/outcome", 'success');
        #set any additional error or warning conditions here
        #there may be cases in which an error occurs and the exit code is 0.
        #we want to set to correct outcome for the running step
        #        if($content =~ m/WSVR0028I:/){
        #            #license expired warning
        #            $ec->setProperty("/myJobStep/outcome", 'warning');
        #        }
    }
    else {
        $ec->setProperty("/myJobStep/outcome", 'error');
    }

}

########################################################################
# createCommandLine - creates the command line for the invocation
# of the program to be executed.
#
# Arguments:
#   -arr: array containing the command name (must be the first element) 
#         and the arguments entered by the user in the UI
#
# Returns:
#   -the command line to be executed by the plugin
#
########################################################################
sub createCommandLine($) {
    my ($arr) = @_;

    my $commandName = @$arr[0];
    my $command = $commandName;
    shift(@$arr);

    foreach my $elem (@$arr) {
        $command .= " $elem";
    }
    return $command;
}

########################################################################
# setProperties - set a group of properties into the Electric Commander
#
# Arguments:
#   -propHash: hash containing the ID and the value of the properties 
#              to be written into the Electric Commander
#
# Returns:
#   none
#
########################################################################
sub setProperties($) {
    my ($propHash) = @_;

    # get an EC object
    my $ec = new ElectricCommander();
    $ec->abortOnError(0);

    foreach my $key (keys % $propHash) {
        my $val = $propHash->{$key};
        $ec->setProperty("/myCall/$key", $val);
    }
}


########################################################################
# registerReports - creates a link for registering the generated report
# in the job step detail
#
# Arguments:
#   -reportFilename: name of the archive which will be linked to the job detail
#   -reportName: name which will be given to the generated linked report
#
# Returns:
#   none
#
########################################################################
sub registerReports($){
    my ($reportFilename, $reportName) = @_;

    if ($reportFilename && $reportFilename ne '') {
        # get an EC object
        my $ec = new ElectricCommander();
        $ec->abortOnError(0);
        $ec->setProperty("/myJob/artifactsDirectory", '');
        $ec->setProperty(
            "/myJob/report-urls/" . $reportName, 
            "jobSteps/$[jobStepId]/" . $reportFilename
        );
    }
}


##########################################################################
# getConfiguration - get the information of the configuration given
#
# Arguments:
#   -configName: name of the configuration to retrieve
#
# Returns:
#   -configToUse: hash containing the configuration information
#
#########################################################################
sub getConfiguration($){
    my ($configName) = @_;

    # get an EC object
    my $ec = new ElectricCommander();
    $ec->abortOnError(0);

    my %configToUse;
    my $proj = "$[/myProject/projectName]";
    my $pluginConfigs = new ElectricCommander::PropDB($ec,"/projects/$proj/weblogic_cfgs");
    my %configRow = $pluginConfigs->getRow($configName);

    # Check if configuration exists
    unless(keys(%configRow)) {
        exit ERROR;
    }

    # Get user/password out of credential
    my $xpath = $ec->getFullCredential($configRow{credential});
    $configToUse{'user'} = $xpath->findvalue("//userName");
    $configToUse{'password'} = $xpath->findvalue("//password");

    foreach my $c (keys %configRow) {
        #getting all values except the credential that was read previously
        if ($c ne CREDENTIAL_ID) {
            $configToUse{$c} = $configRow{$c};
        }
    }
    return %configToUse;
}


sub fixPath($){
    my ($absPath) = @_;

    my $separator;
    if ($absPath && $absPath ne '') {
        if ((substr($absPath, length($absPath)-1,1) eq '\\') || substr($absPath, length($absPath)-1,1) eq '/') {
            return $absPath;
        }
        if ($absPath =~ m/.*\/.+/) {
            $separator = '/';
        }
        elsif ($absPath =~ m/.+\\.+/) {
            $separator = "\\";
        }
        else {
            return '';
        }

        my $fixedPath = $absPath . $separator;
        return $fixedPath;
    }
    else {
        return '';
    }
}


sub setenv {
    my ($script) = @_;
    unless($ENV{_WLST_PERL_DONE}) {
        $ENV{_WLST_PERL_DONE} = 1;
        exec '/bin/sh', '-c', ". $script; exec $^X $0 @ARGV";
    }
    delete $ENV{_WLST_PERL_DONE};
    return 1;
}


main();

1;
