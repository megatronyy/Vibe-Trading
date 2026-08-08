import { Suspense, lazy, type ComponentType } from "react";
import { createBrowserRouter, Navigate } from "react-router";
import { Layout } from "@/components/layout/Layout";
import { isLoggedIn } from "@/lib/apiAuth";

const Home = lazy(() => import("@/pages/Home").then((m) => ({ default: m.Home })));
const Agent = lazy(() => import("@/pages/Agent").then((m) => ({ default: m.Agent })));
const RunDetail = lazy(() =>
  import("@/pages/RunDetail").then((m) => ({ default: m.RunDetail })),
);
const Compare = lazy(() =>
  import("@/pages/Compare").then((m) => ({ default: m.Compare })),
);
const Settings = lazy(() =>
  import("@/pages/Settings").then((m) => ({ default: m.Settings })),
);
const Runtime = lazy(() =>
  import("@/pages/Runtime").then((m) => ({ default: m.Runtime })),
);
const Scheduled = lazy(() =>
  import("@/pages/Scheduled").then((m) => ({ default: m.Scheduled })),
);
const Reports = lazy(() =>
  import("@/pages/Reports").then((m) => ({ default: m.Reports })),
);
const Correlation = lazy(() =>
  import("@/pages/Correlation").then((m) => ({ default: m.Correlation })),
);
const AlphaZoo = lazy(() =>
  import("@/pages/AlphaZoo").then((m) => ({ default: m.AlphaZoo })),
);
const Login = lazy(() => import("@/pages/Login"));

function RequireAuth({ children }: { children: React.ReactNode }) {
  if (!isLoggedIn()) return <Navigate to="/login" replace />;
  return <>{children}</>;
}

function PageLoader() {
  return (
    <div className="flex h-[60vh] items-center justify-center text-muted-foreground">
      Loading…
    </div>
  );
}

function wrap(Component: ComponentType) {
  return (
    <Suspense fallback={<PageLoader />}>
      <Component />
    </Suspense>
  );
}

export const router = createBrowserRouter([
  { path: "/login", element: <Suspense fallback={<PageLoader />}><Login /></Suspense> },
  {
    element: <Layout />,
    children: [
      { path: "/", element: <RequireAuth>{wrap(Agent)}</RequireAuth> },
      { path: "/about", element: wrap(Home) },
      { path: "/agent", element: <RequireAuth>{wrap(Agent)}</RequireAuth> },
      { path: "/runtime", element: <RequireAuth>{wrap(Runtime)}</RequireAuth> },
      { path: "/scheduled", element: <RequireAuth>{wrap(Scheduled)}</RequireAuth> },
      { path: "/reports", element: <RequireAuth>{wrap(Reports)}</RequireAuth> },
      { path: "/settings", element: <RequireAuth>{wrap(Settings)}</RequireAuth> },
      { path: "/runs/:runId", element: <RequireAuth>{wrap(RunDetail)}</RequireAuth> },
      { path: "/compare", element: <RequireAuth>{wrap(Compare)}</RequireAuth> },
      { path: "/correlation", element: <RequireAuth>{wrap(Correlation)}</RequireAuth> },
      { path: "/alpha-zoo", element: <RequireAuth>{wrap(AlphaZoo)}</RequireAuth> },
      { path: "/alpha-zoo/bench", element: <RequireAuth>{wrap(AlphaZoo)}</RequireAuth> },
      { path: "/alpha-zoo/compare", element: <RequireAuth>{wrap(AlphaZoo)}</RequireAuth> },
      { path: "/alpha-zoo/:alphaId", element: <RequireAuth>{wrap(AlphaZoo)}</RequireAuth> },
    ],
  },
]);
