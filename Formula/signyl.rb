# Homebrew formula for Signyl CLI
# Tap: benbrown3/signyl
# Install: brew install benbrown3/signyl/signyl

class Signyl < Formula
  desc "Conversational marketing intelligence CLI"
  homepage "https://signylgrowth.com"
  license "Proprietary"
  version "0.1.14"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/benbrown3/signyl-agent/releases/download/cli-v#{version}/signyl-#{version}-darwin-arm64.tar.gz"
      sha256 "68827ca4cb40223eab14a51fa16055e427eff31e81e710004109c0ef9f2005ed"
    else
      url "https://github.com/benbrown3/signyl-agent/releases/download/cli-v#{version}/signyl-#{version}-darwin-x64.tar.gz"
      sha256 "8455381ef78b605164bbdff3d38c9608bd255077e8aa66e20dba42e59765ed8b"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/benbrown3/signyl-agent/releases/download/cli-v#{version}/signyl-#{version}-linux-arm64.tar.gz"
      sha256 "2035accce5394364de36ecb152f7fe97a6cc16d07b95a0cb641533cc3d100295"
    else
      url "https://github.com/benbrown3/signyl-agent/releases/download/cli-v#{version}/signyl-#{version}-linux-x64.tar.gz"
      sha256 "0478686148d8951af9d2078589f364028dfdc1983d25cd3bfedd22beed59ec24"
    end
  end

  depends_on "node@18"

  resource "python@3.12" do
    on_macos do
      url "https://www.python.org/ftp/python/3.12.7/Python-3.12.7.tgz"
      sha256 "73ac8fe780227bf371add8373c3079f42a0dc62deff8d612cd15a618082ab623"
    end
    on_linux do
      url "https://www.python.org/ftp/python/3.12.7/Python-3.12.7.tgz"
      sha256 "73ac8fe780227bf371add8373c3079f42a0dc62deff8d612cd15a618082ab623"
    end
  end

  def install
    resource("python@3.12").stage do
      system "./configure",
             "--prefix=#{libexec}/python3.12",
             "--enable-optimizations",
             "--with-lto",
             "--disable-test-modules"
      system "make", "-j#{ENV.make_jobs}"
      system "make", "install"
    end

    python = "#{libexec}/python3.12/bin/python3.12"

    libexec.install Dir["lib/*"]
    libexec.install Dir["mcp-servers"] if Dir.exist?("mcp-servers")

    if Dir.exist?("mcp-servers")
      Dir.glob("mcp-servers/*/requirements.txt").each do |req|
        server_dir = File.dirname(req)
        server_name = File.basename(server_dir)
        venv_dir = "#{libexec}/mcp-venvs/#{server_name}"
        system python, "-m", "venv", venv_dir
        system "#{venv_dir}/bin/pip", "install", "-r", req, "-q"
      end
    end

    (libexec/"node_modules").install Dir["node_modules/*"] if Dir.exist?("node_modules")

    libexec.install "dist/main.js"
    libexec.install "package.json"

    (bin/"signyl").write <<~SH
      #!/bin/bash
      export SIGNYL_PYTHON="#{libexec}/python3.12/bin/python3.12"
      export SIGNYL_MCP_VENVS="#{libexec}/mcp-venvs"
      export SIGNYL_LIB="#{libexec}"
      exec "#{Formula["node@18"].opt_bin}/node" "#{libexec}/main.js" "$@"
    SH
  end

  def post_install
    ohai "Signyl CLI installed. Run 'signyl' to start."
    ohai "First-time setup: run 'signyl /credentials' to configure platform connections."
  end

  def caveats
    <<~EOS
      Signyl CLI is installed at #{bin}/signyl.

      To configure platform connections (Google Ads, Meta, Shopify, etc.):
        signyl /credentials

      Credentials are stored in your OS keychain, never in plaintext files.

      For auto-updates, Signyl checks for new versions on each launch.
      To disable: signyl config set auto-update false
    EOS
  end

  test do
    output = shell_output("#{bin}/signyl --version 2>&1", 0)
    assert_match version.to_s, output
  end
end
