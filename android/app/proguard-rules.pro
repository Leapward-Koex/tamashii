# Firebase discovers component registrars from Android manifest metadata and
# constructs them reflectively. Its bundled consumer rule keeps the class name,
# but R8 can still remove the no-argument constructor used at runtime.
-keep class * implements com.google.firebase.components.ComponentRegistrar {
    public <init>();
}
