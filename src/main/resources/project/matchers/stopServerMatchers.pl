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


push (@::gMatchers,
  {
   id =>        "warning",
   pattern =>          q{^Warning:(.+)},
   action =>           q{
    
              my $description = ((defined $::gProperties{"summary"}) ? 
                    $::gProperties{"summary"} : '');
                    
              $description .= "$1";
                              
              setProperty("summary", $description . "\n");
    
   },
  },
  {
   id =>        "serverStopped",
   pattern =>          q{.*Disconnected from weblogic server.*},
   action =>           q{
    
              my $description = ((defined $::gProperties{"summary"}) ? 
                    $::gProperties{"summary"} : '');
                    
              $description .= "Disconnected from weblogic server";
                              
              setProperty("summary", $description . "\n");
    
   },
  },
  
  {
   id =>        "error1",
   pattern =>          q{(Exception|Problem invoking WLST)},
   action =>           q{
    
              my $description = "An unexpected error has occurred, please check the log for more details\n";
              
              
              setProperty("summary", $description);
    
   },
  },  

);
