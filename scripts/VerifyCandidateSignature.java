import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.cert.X509Certificate;
import java.util.HexFormat;
import java.util.HashSet;
import java.util.jar.JarFile;

/** Verify every payload entry; a jarsigner success phrase alone is insufficient. */
class VerifyCandidateSignature {
    public static void main(String[] args) throws Exception {
        String expected = args[1].replace(":", "").toUpperCase();
        var fingerprints = new HashSet<String>();
        int payloadCount = 0;
        try (var jar = new JarFile(Path.of(args[0]).toFile(), true)) {
            var entries = jar.entries();
            byte[] buffer = new byte[65536];
            while (entries.hasMoreElements()) {
                var entry = entries.nextElement();
                if (entry.isDirectory()) continue;
                try (var stream = jar.getInputStream(entry)) {
                    while (stream.read(buffer) != -1) { /* forces digest verification */ }
                }
                // Only JAR signature metadata may be unsigned, not arbitrary META-INF content.
                String name = entry.getName().toUpperCase();
                if (name.equals("META-INF/MANIFEST.MF") ||
                    name.matches("META-INF/[^/]+\\.(SF|RSA|DSA|EC)")) continue;
                var signers = entry.getCodeSigners();
                if (signers == null || signers.length != 1)
                    throw new SecurityException("Unsigned or multiply-signed payload entry");
                var cert = (X509Certificate) signers[0].getSignerCertPath().getCertificates().get(0);
                cert.checkValidity();
                String sha1 = HexFormat.of().withUpperCase().formatHex(
                    MessageDigest.getInstance("SHA-1").digest(cert.getEncoded()));
                if (!sha1.equals(expected)) throw new SecurityException("Upload signer mismatch");
                fingerprints.add(HexFormat.of().withUpperCase().formatHex(
                    MessageDigest.getInstance("SHA-256").digest(cert.getEncoded())));
                payloadCount++;
            }
        }
        if (payloadCount == 0 || fingerprints.size() != 1)
            throw new SecurityException("No consistently signed payload");
        System.out.println(fingerprints.iterator().next());
    }
}
