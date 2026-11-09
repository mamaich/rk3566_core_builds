// LD_PRELOAD test of a fix for Azahar's GLES path on Mali, before the core is rebuilt with it.
// Build on the console: gcc -shared -fPIC -O1 -o glfix.so glfix.c -ldl
//
// azahar-nano's vs_data block carries depth_scale and depth_offset, as fs_data does. Neither block has an
// instance name, so in GLSL ES the members share the global scope, and Mali refuses every program:
// "a uniform block with no instance object vs_data that conflicts with the member of the uniform block
// fs_data". Vulkan compiles each stage to SPIR-V alone, so it never sees the clash.
// RetroArch hands the core GL functions through eglGetProcAddress; this returns wrappers for glCreateShader
// (to know each shader's stage) and glShaderSource, which renames the two identifiers as whole words in every
// shader but the fragment ones: vs_depth_scale, vs_depth_offset. The block is bound by its binding, so the
// names never reach the C++ side. GLFIX_LOG=1 counts the shaders it changed in /tmp/glfix.log.
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef unsigned int GLenum;
typedef unsigned int GLuint;
typedef int GLsizei;
typedef int GLint;
typedef char GLchar;
#define GL_FRAGMENT_SHADER 0x8B30

static GLuint (*real_create)(GLenum);
static void (*real_source)(GLuint, GLsizei, const GLchar *const *, const GLint *);
static void *(*real_gpa)(const char *);
static GLenum types[1 << 16];
static int changed, seen;

static GLuint my_create(GLenum t) {
    GLuint id = real_create(t);
    if (id < (1u << 16)) types[id] = t;
    return id;
}

static int idch(char c) { return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_'; }

static void my_source(GLuint sh, GLsizei n, const GLchar *const *str, const GLint *len) {
    seen++;
    if (sh >= (1u << 16) || types[sh] == GL_FRAGMENT_SHADER || n <= 0) {
        real_source(sh, n, str, len);
        return;
    }
    size_t total = 0;
    for (int i = 0; i < n; i++) total += (len && len[i] >= 0) ? (size_t)len[i] : strlen(str[i]);
    char *src = malloc(total + 1), *p = src;
    for (int i = 0; i < n; i++) {
        size_t l = (len && len[i] >= 0) ? (size_t)len[i] : strlen(str[i]);
        memcpy(p, str[i], l);
        p += l;
    }
    *p = 0;
    // every hit grows the text by 3 bytes ("vs_")
    char *out = malloc(total * 2 + 64), *o = out;
    int hits = 0;
    for (char *s = src; *s;) {
        const char *names[] = {"depth_scale", "depth_offset"};
        int done = 0;
        for (int k = 0; k < 2 && !done; k++) {
            size_t l = strlen(names[k]);
            if (!strncmp(s, names[k], l) && (s == src || !idch(s[-1])) && !idch(s[l])) {
                memcpy(o, "vs_", 3);
                memcpy(o + 3, s, l);
                o += 3 + l;
                s += l;
                hits++;
                done = 1;
            }
        }
        if (!done) *o++ = *s++;
    }
    *o = 0;
    if (hits) changed++;
    const GLchar *one = out;
    real_source(sh, 1, &one, NULL);
    if (getenv("GLFIX_LOG")) {
        FILE *f = fopen("/tmp/glfix.log", "a");
        if (f) {
            fprintf(f, "shader %u type %#x: %d renamed; %d of %d shaders changed\n", sh, types[sh], hits, changed, seen);
            fclose(f);
        }
    }
    free(src);
    free(out);
}


// --- the second fix, tried from outside: RetroArch draws its frame with glVertexAttribPointer and
// glEnable/DisableVertexAttribArray on whatever vertex array is bound, and the core's SwapBuffers
// leaves its present VAO bound (current_state.Apply() after video_cb). RetroArch's calls come
// straight from libGLESv2 (by symbol), the core's through eglGetProcAddress; when one of RetroArch's
// lands on a vertex array other than 0, the default one is bound first, which is what the core will
// do itself ("leave VAO 0 bound for the frontend"). GLFIX_NOVAO=1 turns this part off.
static GLuint cur_vao;
static void (*r_bva)(GLuint);
static void my_bva(GLuint v) { cur_vao = v; r_bva(v); }
static void *nxt(const char *n) { return dlsym(RTLD_NEXT, n); }
static int vao_guard = -1;
static void guard(void) {
    if (vao_guard < 0) vao_guard = getenv("GLFIX_NOVAO") ? 0 : 1;
    if (vao_guard && cur_vao != 0) {
        if (!r_bva) r_bva = nxt("glBindVertexArray");
        r_bva(0);
        cur_vao = 0;
    }
}
void glBindVertexArray(GLuint v) { if (!r_bva) r_bva = nxt("glBindVertexArray"); cur_vao = v; r_bva(v); }
void glVertexAttribPointer(GLuint i, GLint sz, GLenum ty, unsigned char n, GLsizei st, const void *p) {
    static void (*r)(GLuint, GLint, GLenum, unsigned char, GLsizei, const void *);
    if (!r) r = nxt("glVertexAttribPointer");
    guard();
    r(i, sz, ty, n, st, p);
}
void glEnableVertexAttribArray(GLuint i) {
    static void (*r)(GLuint);
    if (!r) r = nxt("glEnableVertexAttribArray");
    guard();
    r(i);
}
void glDisableVertexAttribArray(GLuint i) {
    static void (*r)(GLuint);
    if (!r) r = nxt("glDisableVertexAttribArray");
    guard();
    r(i);
}


// diagnostics for the precompiled shader cache: what Mali reports as binary formats, what it saves
static void (*r_giv)(GLenum, GLint *);
static void (*r_gpb)(GLuint, GLsizei, GLsizei *, GLenum *, void *);
static void glog(const char *fmt, long a, long b) {
    if (!getenv("GLFIX_LOG")) return;
    FILE *f = fopen("/tmp/glfix.log", "a");
    if (f) { fprintf(f, fmt, a, b); fputc(10, f); fclose(f); }
}
// GLFIX_BINFMT=0x8f61: Mali (g29p1) reports no program binary formats, so Azahar throws its whole precompiled
// cache away at every start; report this one format instead, to see whether glProgramBinary takes them.
static void my_giv(GLenum p, GLint *v) {
    r_giv(p, v);
    const char *fake = getenv("GLFIX_BINFMT");
    if (p == 0x87FE) { glog("GL_NUM_PROGRAM_BINARY_FORMATS = %ld %ld", v[0], 0); if (fake && v[0] == 0) v[0] = 1; }
    if (p == 0x87FF) { if (fake) v[0] = (GLint)strtol(fake, 0, 0); glog("GL_PROGRAM_BINARY_FORMATS[0] = %#lx %ld", v[0], 0); }
}
static void my_gpb(GLuint prog, GLsizei bs, GLsizei *len, GLenum *fmt, void *bin) {
    r_gpb(prog, bs, len, fmt, bin);
    static int n;
    if (n++ < 5) glog("glGetProgramBinary: format %#lx, buffer %ld", fmt ? (long)*fmt : -1, bs);
}

void *eglGetProcAddress(const char *name) {
    if (!real_gpa) real_gpa = dlsym(RTLD_NEXT, "eglGetProcAddress");
    void *f = real_gpa(name);
    if (!f || !name) return f;
    if (!strcmp(name, "glCreateShader")) {
        real_create = f;
        return (void *)my_create;
    }
    if (!strcmp(name, "glShaderSource")) {
        real_source = f;
        return (void *)my_source;
    }
    if (!strcmp(name, "glGetIntegerv")) {
        r_giv = f;
        return (void *)my_giv;
    }
    if (!strcmp(name, "glGetProgramBinary")) {
        r_gpb = f;
        return (void *)my_gpb;
    }
    if (!strcmp(name, "glBindVertexArray")) {
        r_bva = f;
        return (void *)my_bva;
    }
    return f;
}
