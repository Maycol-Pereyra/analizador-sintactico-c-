import os
import subprocess
import sys
import tempfile
import tkinter as tk
from tkinter import ttk, messagebox, filedialog

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PARSER_EXE = os.path.join(ROOT_DIR, "parser.exe")
EJEMPLOS_DIR = os.path.join(ROOT_DIR, "tests", "ejemplos")


def parse_output(stdout):
    """Convierte el texto de parser.exe en (nodos, errores, resultado).

    nodos:  [(profundidad, etiqueta)]   errores: [(linea, columna, mensaje)]
    resultado: "OK" o "ERRORES"
    """
    nodos, errores, resultado = [], [], None
    for line in stdout.splitlines():
        if line.startswith("NODO|"):
            _, depth, label = line.split("|", 2)
            nodos.append((int(depth), label))
        elif line.startswith("ERROR|"):
            _, linea, col, msg = line.split("|", 3)
            errores.append((int(linea), int(col), msg))
        elif line.startswith("RESULTADO|"):
            resultado = line.split("|")[1]
    return nodos, errores, resultado


def run_parser(source_text):
    if not os.path.exists(PARSER_EXE):
        raise FileNotFoundError(
            "No se encontro parser.exe. Corre build.ps1 primero para compilarlo."
        )
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".txt", delete=False, encoding="utf-8"
    ) as f:
        f.write(source_text)
        tmp_path = f.name
    try:
        creationflags = subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
        result = subprocess.run(
            [PARSER_EXE, tmp_path],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            creationflags=creationflags,
        )
    finally:
        os.remove(tmp_path)
    return parse_output(result.stdout)


class ParserApp:
    def __init__(self, root):
        self.root = root
        root.title("Analizador Sintactico - Mini-C")
        root.geometry("1100x650")

        paned = ttk.PanedWindow(root, orient=tk.HORIZONTAL)
        paned.pack(fill=tk.BOTH, expand=True, padx=8, pady=8)

        left = ttk.Frame(paned)
        paned.add(left, weight=1)
        ttk.Label(left, text="Codigo fuente:").pack(anchor="w")
        self.text = tk.Text(left, wrap="none", font=("Consolas", 11), undo=True)
        self.text.pack(fill=tk.BOTH, expand=True)
        self.text.tag_configure("err", background="#ffcccc")

        btns = ttk.Frame(left)
        btns.pack(fill=tk.X, pady=6)
        ttk.Button(btns, text="Analizar (F5)", command=self.analizar).pack(side=tk.LEFT)
        ttk.Button(btns, text="Abrir archivo...", command=self.abrir).pack(side=tk.LEFT, padx=6)
        self.status = ttk.Label(btns, text="")
        self.status.pack(side=tk.LEFT, padx=10)
        root.bind("<F5>", lambda e: self.analizar())

        right = ttk.Notebook(paned)
        paned.add(right, weight=1)

        self.tree = ttk.Treeview(right, show="tree")
        right.add(self.tree, text="Arbol sintactico")

        self.errs = ttk.Treeview(right, columns=("linea", "columna", "mensaje"), show="headings")
        for col, width in (("linea", 60), ("columna", 70), ("mensaje", 480)):
            self.errs.heading(col, text=col.capitalize())
            self.errs.column(col, width=width)
        self.errs.bind("<Double-1>", self.ir_a_error)
        right.add(self.errs, text="Errores")
        self.tabs = right

    def abrir(self):
        path = filedialog.askopenfilename(
            initialdir=EJEMPLOS_DIR, filetypes=[("Texto", "*.txt"), ("Todos", "*.*")]
        )
        if path:
            with open(path, encoding="utf-8", errors="replace") as f:
                self.text.delete("1.0", tk.END)
                self.text.insert("1.0", f.read())

    def ir_a_error(self, _event):
        sel = self.errs.selection()
        if sel:
            linea, col, _ = self.errs.item(sel[0], "values")
            self.text.mark_set(tk.INSERT, f"{linea}.{int(col) - 1}")
            self.text.see(tk.INSERT)
            self.text.focus_set()

    def analizar(self):
        self.tree.delete(*self.tree.get_children())
        self.errs.delete(*self.errs.get_children())
        self.text.tag_remove("err", "1.0", tk.END)
        try:
            nodos, errores, resultado = run_parser(self.text.get("1.0", tk.END))
        except FileNotFoundError as e:
            messagebox.showerror("Falta compilar", str(e))
            return

        padres = []  # padres[d] = id del ultimo nodo insertado a profundidad d
        for depth, label in nodos:
            parent = padres[depth - 1] if depth else ""
            iid = self.tree.insert(parent, tk.END, text=label, open=True)
            del padres[depth:]
            padres.append(iid)

        for linea, col, msg in errores:
            self.errs.insert("", tk.END, values=(linea, col, msg))
            self.text.tag_add("err", f"{linea}.0", f"{linea}.end")

        if resultado == "OK":
            self.status.config(text="Sintaxis correcta")
            self.tabs.select(self.tree)
        else:
            self.status.config(text=f"{len(errores)} errores sintacticos")
            self.tabs.select(self.errs)


def main():
    root = tk.Tk()
    ParserApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
