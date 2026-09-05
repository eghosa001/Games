# Live Browser QA

The live QA workflow uses Vercel's open-source `agent-browser` CLI with Chrome to exercise the deployed Godot Web build. It captures startup/opening-loop/mobile screenshots plus browser console and page-error diagnostics as GitHub Actions artifacts.

Run it from **Actions → Live Browser QA → Run workflow** and optionally provide a deployment URL. The default is the current RENEW Vercel deployment.
