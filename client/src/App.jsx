import { useEffect, useState } from "react";

export default function App() {
  const [health, setHealth] = useState(null);
  const [error, setError] = useState("");

  useEffect(() => {
    fetch("/api/health")
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
      })
      .then(setHealth)
      .catch((err) => setError(err.message));
  }, []);

  return (
    <main className="page">
      <p className="eyebrow">Vite + Node · ECR · EC2</p>
      <h1>Deploy pipeline is live</h1>
      <p className="lead">
        Push to <code>main</code>. GitHub Actions builds a Docker image, pushes
        it to ECR, then EC2 pulls and rolls the new container.
      </p>

      <section className="card">
        <h2>API status</h2>
        {error && <p className="error">Could not reach API: {error}</p>}
        {!error && !health && <p>Checking /api/health…</p>}
        {health && (
          <dl>
            <div>
              <dt>Status</dt>
              <dd>{health.status}</dd>
            </div>
            <div>
              <dt>Version</dt>
              <dd>{health.version}</dd>
            </div>
            <div>
              <dt>Git SHA</dt>
              <dd>
                <code>{health.gitSha}</code>
              </dd>
            </div>
            <div>
              <dt>Image</dt>
              <dd>
                <code>{health.image}</code>
              </dd>
            </div>
            <div>
              <dt>Time</dt>
              <dd>{health.time}</dd>
            </div>
          </dl>
        )}
      </section>
    </main>
  );
}
