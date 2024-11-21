class DnsLoadBalancer < Formula
  desc "Rust-based DNS load-balancer for Kubernetes and public DNS servers"
  homepage "https://github.com/kometen/dns-load-balancer"
  url "https://github.com/kometen/dns-load-balancer/archive/refs/tags/v0.1.1.tar.gz"
  sha256 "73e5f1043ab34b6319337d0efdad4022c0879d430f9a988d4cf35fcee3bde0e8"
  license "MIT"

  bottle do
    root_url "https://github.com/kometen/homebrew-dns-load-balancer/releases/download/dns-load-balancer-0.1.1"
    rebuild 1
    sha256 cellar: :any_skip_relocation, arm64_sequoia: "7403a91b98740ef5f8a9fa1ae5cfd9162ce0329c54b6a84d0f794891e6bbe41c"
    sha256 cellar: :any_skip_relocation, ventura:       "4a30cdd1981f126e17894bc5d972a3bbeae9425c7b2d1e15e48bb969c17134f7"
    sha256 cellar: :any_skip_relocation, x86_64_linux:  "f3cba1e1deefc269513123dd4ac75bb28dad302a7c5f52817ce1577f0710eb3c"
  end

  depends_on "rust" => :build

  def plist?
    false
  end

  def install
    system "cargo", "install", *std_cargo_args

    # Create necessary directories
    (etc/"dns_load_balancer").mkpath
    (var/"log/dns_load_balancer").mkpath

    # Install binary
    sbin.install "target/release/dns_load_balancer"

    # Install default config file
    (etc/"dns_load_balancer").install "config.toml"

    # Create LaunchDaemon plist
    (prefix/"com.github.kometen.dns-load-balancer.plist.conf").write daemon_plist_content
  end

  def daemon_plist_content
    <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>com.github.kometen.dns-load-balancer</string>
        <key>ProgramArguments</key>
        <array>
          <string>#{opt_sbin}/dns_load_balancer</string>
          <string>run</string>
          <string>--config</string>
          <string>#{etc}/dns_load_balancer/config.toml</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>KeepAlive</key>
        <true/>
        <key>StandardErrorPath</key>
        <string>#{var}/log/dns_load_balancer/error.log</string>
        <key>StandardOutPath</key>
        <string>#{var}/log/dns_load_balancer/output.log</string>
      </dict>
      </plist>
    EOS
  end

  def caveats
    <<~EOS
      DNS Load Balancer requires elevated privileges to bind to port 53.

      Quick Start:
        1. Start manually (requires sudo):
           sudo #{opt_sbin}/dns_load_balancer run --config #{etc}/dns_load_balancer/config.toml

      Alternative Setup (recommended for automatic startup):
        1. Copy binary to system location:
           sudo cp #{opt_sbin}/dns_load_balancer /usr/local/sbin/

        2. Set set-user-id bit to allow port 53 binding:
           sudo chmod 4755 /usr/local/sbin/dns_load_balancer

        3. Install LaunchDaemon for automatic startup:
           sudo cp #{prefix}/com.github.kometen.dns-load-balancer.plist.conf /Library/LaunchDaemons/com.github.kometen.dns-load-balancer.plist
           sudo chown root:wheel /Library/LaunchDaemons/com.github.kometen.dns-load-balancer.plist
           sudo chmod 644 /Library/LaunchDaemons/com.github.kometen.dns-load-balancer.plist

        4. Load the service:
           sudo launchctl load -w /Library/LaunchDaemons/com.github.kometen.dns-load-balancer.plist

      Configuration:
        Config file: #{etc}/dns_load_balancer/config.toml
        Logs: #{var}/log/dns_load_balancer/

      Note: The service will automatically drop privileges after binding to port 53
            if started with elevated permissions or set-user-id bit.

      Manual Control:
        Start: sudo launchctl start com.github.kometen.dns-load-balancer
        Stop:  sudo launchctl stop com.github.kometen.dns-load-balancer
        Status: sudo launchctl list | grep dns-load-balancer
    EOS
  end

  test do
    output = shell_output("#{opt_sbin}/dns_load_balancer example | /usr/bin/head -1 | tr -d '\n' 2>&1")
    expected = "[[servers]]"
    assert_match expected, output

    assert_match version.to_s, shell_output("#{opt_sbin}/dns_load_balancer --version")
  end
end
