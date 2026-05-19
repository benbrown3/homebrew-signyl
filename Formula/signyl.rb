# Homebrew formula for Signyl CLI
# Tap: benbrown3/signyl
# Install: brew install benbrown3/signyl/signyl

class Signyl < Formula
  desc "Conversational marketing intelligence CLI"
  homepage "https://signylgrowth.com"
  license "Proprietary"
  version "0.1.10"

  on_macos do
    if Hardware::CPU.arm?
      url "https://github.com/benbrown3/signyl-agent/releases/download/cli-v#{version}/signyl-#{version}-darwin-arm64.tar.gz"
      sha256 "c7a7ced074f1a4ebbf736300e1e2212fd8268f591272ba1c0f50750173c244ba"
    else
      url "https://github.com/benbrown3/signyl-agent/releases/download/cli-v#{version}/signyl-#{version}-darwin-x64.tar.gz"
      sha256 "92f81cb09d37852d334276421a978d62dcc0f87220d4e536e709d2ab33877621"
    end
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://github.com/benbrown3/signyl-agent/releases/download/cli-v#{version}/signyl-#{version}-linux-arm64.tar.gz"
      sha256 "3585bbdaf1c86685362a51c49cdcdb639f61b1c3f2bcdbfb4f60b3b284027985"
    else
      url "https://github.com/benbrown3/signyl-agent/releases/download/cli-v#{version}/signyl-#{version}-linux-x64.tar.gz"
      sha256 "fa046db20bd596bd75aef6d0c9cc9fd1006a39edf6d72b3f345f33aacb05a624"
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
