import 'package:fantastic_guacamole/l10n/chronospark_localizations.dart';
import 'package:flutter/widgets.dart';

/// App-authored access notices only; never translate account/user content.
String authStatusText(BuildContext context, String value, {String? fallback}) {
  if (!ChronoSparkLocalizations.of(context).isSpanish) return value;
  const spanish = <String, String>{
    'Authentication unavailable': 'Acceso no disponible',
    'Sign-in services unavailable': 'Inicio de sesión no disponible',
    'Auth initialization failed. Retry when ready.':
        'No se pudo preparar el acceso. Inténtalo de nuevo cuando puedas.',
    'Auth initialization timed out. Please retry.':
        'Se agotó el tiempo para preparar el acceso. Inténtalo de nuevo.',
    'Authentication initialization timed out.':
        'Se agotó el tiempo para preparar el acceso.',
    'Auth service is not ready in this runtime.':
        'El servicio de acceso no está disponible ahora.',
    'Auth service reported an error. Retry the connection.':
        'El servicio de acceso informó de un error. Vuelve a intentar la conexión.',
    'Local profile storage could not be opened. Retry to protect your saved data.':
        'No se pudo abrir el almacenamiento del perfil local. Inténtalo de nuevo para proteger tus datos guardados.',
    'Sign-in services are temporarily unavailable.':
        'El inicio de sesión no está disponible temporalmente.',
    'Authentication backend is configured but unavailable in this runtime.':
        'El servicio de acceso está configurado, pero no está disponible ahora.',
    'Authentication backend unavailable for this runtime.':
        'El servicio de acceso no está disponible ahora.',
    'Retry sign-in services': 'Reintentar inicio de sesión',
    'Stopping safely': 'Deteniendo de forma segura',
    'Enter a valid email.': 'Introduce un correo válido.',
    'Password required.': 'Introduce tu contraseña.',
    'Use 8+ chars with upper, lower, and a number.':
        'Usa al menos 8 caracteres, con mayúsculas, minúsculas y un número.',
    'Passwords do not match.': 'Las contraseñas no coinciden.',
    'Enter account email, then trigger password reset.':
        'Introduce el correo de la cuenta y solicita restablecer la contraseña.',
    'Verification link sent. Confirm inbox to proceed.':
        'Se envió el enlace de verificación. Revisa tu correo para continuar.',
    'Password reset link sent.':
        'Se envió el enlace para restablecer la contraseña.',
    'Password updated.': 'Contraseña actualizada.',
    'Password reset verified. Set your new password below.':
        'Se verificó la recuperación. Escribe tu nueva contraseña a continuación.',
    'Reset link received. Secure verification is required; request a new email if this link has expired.':
        'Se recibió el enlace de recuperación. Debe verificarse de forma segura; solicita otro correo si el enlace caducó.',
    'Email verification callback received. Continue sign-in if needed.':
        'Se recibió la verificación del correo. Continúa con el inicio de sesión si es necesario.',
    'Authentication callback received. Continuing sign-in flow.':
        'Se recibió la confirmación de acceso. Continuando el inicio de sesión.',
  };
  return spanish[value] ?? fallback ?? value;
}
