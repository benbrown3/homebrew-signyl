# Homebrew formula for Signyl CLI
# Tap: benbrown3/signyl
# Install: brew install benbrown3/signyl/signyl

class Signyl < Formula
  desc "Conversational marketing intelligence CLI"
  homepage "https://signylgrowth.com"
  license "Proprietary"
  version "0.1.2"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/benbrown3/signyl-agent/releases/download/cli-v#{version}/signyl-#{version}-darwin-arm64.tar.gz"
      sha256 "1a9b5697bb22a23cdfbe768e6c16e624aa5766a025adfe902b97a24586271d65"
    else
      url "https://github.com/benbrown3/signyl-agent/releases/download/cli-v#{version}/signyl-#{version}-darwin-x64.tar.gz"
      sha256 "9050023a5b59b1b30f2849986794fb5ba0fa2836555a4d79dd6a127ee0167597"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/benbrown3/signyl-agent/releases/download/cli-v#{version}/signyl-#{version}-linux-arm64.tar.gz"
      sha256 "08e2e3f15f393a2a9f96ab276498af2bc80cda21b23b969478494903eaf3d5c2"
    else
      url "https://github.com/benbrown3/signyl-agent/releases/download/cli-v#{version}/signyl-#{version}-linux-x64.tar.gz"
      sha256 "b72fbc5dfe33dae62135844248ab8ae8ea117ee365ceca24384f06484c9c0ca7"
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
