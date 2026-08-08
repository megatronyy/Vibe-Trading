import { useState } from "react";
import { useNavigate } from "react-router";
import { api } from "@/lib/api";
import { setJwt } from "@/lib/apiAuth";

export default function Login() {
  const navigate = useNavigate();
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [isRegister, setIsRegister] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      const fn = isRegister ? api.register : api.login;
      const data = await fn(username.trim(), password);
      setJwt(data.jwt);
      navigate("/agent");
    } catch (err) {
      setError(err instanceof Error ? err.message : "登录失败");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-background px-4">
      <div className="w-full max-w-sm space-y-6">
        <div className="text-center">
          <div className="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-gradient-to-br from-primary to-info mb-3">
            <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2">
              <path d="M12 2L2 7l10 5 10-5-10-5z" />
              <path d="M2 17l10 5 10-5M2 12l10 5 10-5" />
            </svg>
          </div>
          <h1 className="text-2xl font-bold text-foreground">AI Trading</h1>
          <p className="text-sm text-muted-foreground mt-1">
            {isRegister ? "创建账户" : "登录你的账户"}
          </p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-3">
          <input
            type="text"
            placeholder="用户名"
            value={username}
            onChange={(e) => setUsername(e.target.value)}
            className="w-full rounded-lg border bg-background px-4 py-2.5 text-sm focus:ring-2 focus:ring-primary/40 outline-none"
            autoComplete="username"
            required
          />
          <input
            type="password"
            placeholder="密码"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="w-full rounded-lg border bg-background px-4 py-2.5 text-sm focus:ring-2 focus:ring-primary/40 outline-none"
            autoComplete={isRegister ? "new-password" : "current-password"}
            required
          />
          {error && (
            <p className="text-sm text-danger bg-danger/5 border border-danger/20 rounded-lg px-3 py-2">{error}</p>
          )}
          <button
            type="submit"
            disabled={loading || !username.trim() || !password}
            className="w-full rounded-lg bg-primary text-primary-foreground py-2.5 text-sm font-medium disabled:opacity-50 hover:opacity-90 transition-opacity"
          >
            {loading ? "请稍候…" : isRegister ? "注册" : "登录"}
          </button>
        </form>

        <button
          onClick={() => { setError(""); setIsRegister(!isRegister); }}
          className="w-full text-sm text-muted-foreground hover:text-foreground transition-colors"
        >
          {isRegister ? "已有账户？去登录" : "没有账户？去注册"}
        </button>
      </div>
    </div>
  );
}
