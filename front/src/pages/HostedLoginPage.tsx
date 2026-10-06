import { useEffect, useRef, useState } from "react"
import { LoaderCircle } from "lucide-react"
import { Link, Navigate } from "react-router"

import { AuthLayout } from "@/components/auth/AuthLayout"
import { hostedUiEnabled, startHostedSignIn } from "@/lib/auth"

/** /login/: sends the browser straight to Cognito's sign-in page (password and Google). */
export function HostedLoginPage() {
  const enabled = hostedUiEnabled()
  const [failed, setFailed] = useState(false)
  // StrictMode runs effects twice in development; a second start would overwrite the state and
  // PKCE verifier saved by the first one, and the callback would reject the code.
  const started = useRef(false)

  useEffect(() => {
    if (!enabled || started.current) return
    started.current = true
    startHostedSignIn().catch(() => setFailed(true))
  }, [enabled])

  // Local development without Cognito: fall back to the app's own sign-in form.
  if (!enabled) return <Navigate to="/" replace />

  return (
    <AuthLayout>
      {failed ? (
        <div role="alert">
          <h1 className="text-2xl font-semibold text-foreground">Could not start sign-in</h1>
          <Link
            to="/"
            className="mt-6 inline-block font-medium text-primary underline-offset-4 hover:underline"
          >
            Back to sign in
          </Link>
        </div>
      ) : (
        <p className="flex items-center gap-2 text-muted-foreground">
          <LoaderCircle className="size-5 animate-spin" /> Redirecting to sign-in…
        </p>
      )}
    </AuthLayout>
  )
}
