# -*- coding: utf-8 -*-

import math
import tkinter as tk
from tkinter import ttk, messagebox

import numpy as np

from matplotlib.figure import Figure
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg


# ============================================================
# FUNCOES GERAIS
# ============================================================

def converter_float(texto):
    """Aceita ponto ou virgula como separador decimal."""
    return float(texto.strip().replace(",", "."))


def selecionar_metodo(area_km2, tc_h):
    """
    Identifica o criterio geral.

    Nesta versao, o calculo completo implementado e:
    A > 20 km2 e Tc < 24 h
    """

    if area_km2 <= 5.0:
        return {
            "codigo": "racional",
            "descricao": "Area <= 5 km2: Metodo Racional."
        }

    if area_km2 <= 10.0:
        return {
            "codigo": "racional_corrigido",
            "descricao": "5 < Area <= 10 km2: Metodo Racional Corrigido."
        }

    if area_km2 <= 20.0:
        return {
            "codigo": "hut_simples",
            "descricao": (
                "10 < Area <= 20 km2: "
                "Hidrograma Sintetico Triangular."
            )
        }

    if tc_h < 24.0:
        return {
            "codigo": "hut_4_blocos",
            "descricao": (
                "Area > 20 km2 e Tc < 24 h:\n"
                "4 hidrogramas parciais.\n"
                "Delta t = Tc / 4."
            )
        }

    return {
        "codigo": "hut_6h",
        "descricao": (
            "Area > 20 km2 e Tc >= 24 h:\n"
            "criterio ainda nao implementado nesta versao."
        )
    }


# ============================================================
# HUT
# ============================================================

def calcular_parametros_hut(area_km2, tc_h):

    dt = tc_h / 4.0

    tp = dt / 2.0 + 0.6 * tc_h

    tr = 1.67 * tp

    tb = 2.67 * tp

    mu = 2.08 * area_km2 / tp

    return {
        "dt": dt,
        "tp": tp,
        "tr": tr,
        "tb": tb,
        "mu": mu
    }


def ordenada_hut(t, tp, tr, tb, mu):
    """
    Ordenada do HUT unitario em m3/s/cm.
    """

    if t < 0.0:
        return 0.0

    if t <= tp:
        return mu * t / tp

    if t <= tb:
        return mu * (tb - t) / tr

    return 0.0


# ============================================================
# PRECIPITACAO
# ============================================================

def coeficiente_reducao_area(area_km2):
    """
    Coeficiente de reducao espacial utilizado
    nesta implementacao.
    """

    return 1.0 - 0.10 * math.log10(area_km2 / 25.0)


def precipitacao_efetiva(pm_mm, cn):
    """
    Precipitacao efetiva acumulada pelo metodo SCS/CN.

    Resultado em mm.
    """

    if not 0.0 < cn <= 100.0:
        raise ValueError("CN deve estar entre 0 e 100.")

    ia = 5080.0 / cn - 50.8

    if pm_mm <= ia:
        return 0.0

    numerador = (
        pm_mm
        - 5080.0 / cn
        + 50.8
    ) ** 2

    denominador = (
        pm_mm
        + 20320.0 / cn
        - 203.2
    )

    return numerador / denominador


def calcular_chuvas(area, cn, precipitacoes):

    cr = coeficiente_reducao_area(area)

    resultados = []

    pe_anterior = 0.0

    for i, pi in enumerate(precipitacoes, start=1):

        pm = pi * cr

        pe = precipitacao_efetiva(
            pm,
            cn
        )

        delta_pe = pe - pe_anterior

        if delta_pe < -1e-9:
            raise ValueError(
                "Foi obtido incremento de chuva efetiva negativo.\n"
                "Verifique se as precipitacoes acumuladas Pi "
                "estao em ordem crescente."
            )

        delta_pe = max(
            delta_pe,
            0.0
        )

        resultados.append({
            "bloco": i,
            "pi": pi,
            "pm": pm,
            "pe": pe,
            "delta_pe_mm": delta_pe,
            "q_cm": delta_pe / 10.0
        })

        pe_anterior = pe

    return cr, resultados


# ============================================================
# HIDROGRAMAS PARCIAIS
# ============================================================

def vazao_parcial(t, deslocamento, q_cm, parametros):
    """
    q_cm * HUT deslocado no tempo.
    Resultado em m3/s.
    """

    t_local = t - deslocamento

    hu = ordenada_hut(
        t_local,
        parametros["tp"],
        parametros["tr"],
        parametros["tb"],
        parametros["mu"]
    )

    return q_cm * hu


def vazao_total(t, chuvas, parametros):
    """
    Soma de todos os hidrogramas parciais.
    """

    dt = parametros["dt"]

    total = 0.0

    for j, chuva in enumerate(chuvas):

        deslocamento = j * dt

        total += vazao_parcial(
            t,
            deslocamento,
            chuva["q_cm"],
            parametros
        )

    return total


def encontrar_pico_exato(chuvas, parametros):
    """
    Como os hidrogramas sao lineares por trechos,
    o pico da soma ocorre em um dos pontos de mudanca
    de declividade.

    Assim, avaliamos:
    - inicio de cada HUT;
    - pico de cada HUT;
    - final de cada HUT.
    """

    dt = parametros["dt"]
    tp = parametros["tp"]
    tb = parametros["tb"]

    candidatos = []

    for j in range(len(chuvas)):

        deslocamento = j * dt

        candidatos.append(
            deslocamento
        )

        candidatos.append(
            deslocamento + tp
        )

        candidatos.append(
            deslocamento + tb
        )

    candidatos = sorted(
        set(candidatos)
    )

    melhor_t = None
    melhor_q = -1.0

    for t in candidatos:

        q = vazao_total(
            t,
            chuvas,
            parametros
        )

        if q > melhor_q:
            melhor_q = q
            melhor_t = t

    return melhor_t, melhor_q


# ============================================================
# APLICACAO
# ============================================================

class AplicacaoHUT(tk.Tk):

    def __init__(self):

        super().__init__()

        self.title(
            "HUT - GOINFRA IP-03/2023"
        )

        self.geometry(
            "1550x920"
        )

        self.minsize(
            1250,
            760
        )

        self.parametros = None
        self.chuvas = None

        self.criar_estilos()
        self.criar_interface()
        self.preencher_valores_iniciais()

        self.after(
            300,
            self.calcular
        )

    # ========================================================
    # ESTILO
    # ========================================================

    def criar_estilos(self):

        style = ttk.Style(self)

        try:
            style.theme_use("vista")
        except tk.TclError:
            pass

        style.configure(
            "Titulo.TLabel",
            font=("Segoe UI", 15, "bold"),
            foreground="#0b4dbb"
        )

        style.configure(
            "Subtitulo.TLabel",
            font=("Segoe UI", 10, "bold"),
            foreground="#0b4dbb"
        )

        style.configure(
            "Normal.TLabel",
            font=("Segoe UI", 10)
        )

        style.configure(
            "Destaque.TLabel",
            font=("Segoe UI", 10, "bold"),
            foreground="#0b4dbb"
        )

        style.configure(
            "Calcular.TButton",
            font=("Segoe UI", 11, "bold"),
            padding=8
        )

        style.configure(
            "Treeview",
            font=("Segoe UI", 9),
            rowheight=25
        )

        style.configure(
            "Treeview.Heading",
            font=("Segoe UI", 9, "bold")
        )

    # ========================================================
    # ESTRUTURA DA JANELA
    # ========================================================

    def criar_interface(self):

        self.columnconfigure(
            0,
            weight=0
        )

        self.columnconfigure(
            1,
            weight=1
        )

        self.rowconfigure(
            0,
            weight=1
        )

        self.rowconfigure(
            1,
            weight=0
        )

        self.frame_esquerdo = ttk.Frame(
            self,
            padding=15
        )

        self.frame_esquerdo.grid(
            row=0,
            column=0,
            sticky="nsew"
        )

        self.frame_direito = ttk.Frame(
            self,
            padding=(5, 15, 15, 10)
        )

        self.frame_direito.grid(
            row=0,
            column=1,
            sticky="nsew"
        )

        self.frame_direito.columnconfigure(
            0,
            weight=1
        )

        self.frame_direito.rowconfigure(
            0,
            weight=1
        )

        self.frame_direito.rowconfigure(
            1,
            weight=0
        )

        self.criar_entradas()

        self.criar_abas_graficos()

        self.criar_resultados()

        self.criar_status()

    # ========================================================
    # ENTRADAS
    # ========================================================

    def criar_entradas(self):

        ttk.Label(
            self.frame_esquerdo,
            text="DADOS DE ENTRADA",
            style="Titulo.TLabel"
        ).pack(
            anchor="w",
            pady=(0, 15)
        )

        self.entry_area = self.criar_campo(
            "Area da bacia A [km2]"
        )

        self.entry_tc = self.criar_campo(
            "Tempo de concentracao Tc [h]"
        )

        self.entry_cn = self.criar_campo(
            "Numero de Curva CN"
        )

        self.entry_tr = self.criar_campo(
            "Tempo de retorno TR [anos]"
        )

        # ----------------------------------------------------
        # PRECIPITACOES
        # ----------------------------------------------------

        frame_prec = ttk.LabelFrame(
            self.frame_esquerdo,
            text="PRECIPITACOES ACUMULADAS Pi",
            padding=10
        )

        frame_prec.pack(
            fill="x",
            pady=(5, 12)
        )

        ttk.Label(
            frame_prec,
            text="Bloco"
        ).grid(
            row=0,
            column=0,
            padx=4
        )

        ttk.Label(
            frame_prec,
            text="Tempo min"
        ).grid(
            row=0,
            column=1,
            padx=4
        )

        ttk.Label(
            frame_prec,
            text="Pi mm"
        ).grid(
            row=0,
            column=2,
            padx=4
        )

        self.labels_tempos = []
        self.entries_prec = []

        for i in range(4):

            ttk.Label(
                frame_prec,
                text=str(i + 1)
            ).grid(
                row=i + 1,
                column=0,
                padx=5,
                pady=3
            )

            lbl_tempo = ttk.Label(
                frame_prec,
                text="--"
            )

            lbl_tempo.grid(
                row=i + 1,
                column=1,
                padx=8
            )

            self.labels_tempos.append(
                lbl_tempo
            )

            entry = ttk.Entry(
                frame_prec,
                width=12,
                justify="center"
            )

            entry.grid(
                row=i + 1,
                column=2,
                padx=5,
                pady=3
            )

            self.entries_prec.append(
                entry
            )

        ttk.Label(
            frame_prec,
            text=(
                "Para este caso: "
                "Delta t = Tc/4"
            ),
            font=("Segoe UI", 9, "italic")
        ).grid(
            row=5,
            column=0,
            columnspan=3,
            pady=(8, 0)
        )

        # ----------------------------------------------------
        # BOTOES
        # ----------------------------------------------------

        ttk.Button(
            self.frame_esquerdo,
            text="CALCULAR",
            style="Calcular.TButton",
            command=self.calcular
        ).pack(
            fill="x",
            pady=(0, 8)
        )

        ttk.Button(
            self.frame_esquerdo,
            text="LIMPAR",
            command=self.limpar
        ).pack(
            fill="x",
            pady=(0, 12)
        )

        # ----------------------------------------------------
        # CRITERIO
        # ----------------------------------------------------

        frame_criterio = ttk.LabelFrame(
            self.frame_esquerdo,
            text="CRITERIO APLICAVEL",
            padding=10
        )

        frame_criterio.pack(
            fill="x",
            pady=(0, 10)
        )

        self.label_criterio = ttk.Label(
            frame_criterio,
            text="--",
            justify="left",
            wraplength=280
        )

        self.label_criterio.pack(
            anchor="w"
        )

        # ----------------------------------------------------
        # CHUVAS EFETIVAS
        # ----------------------------------------------------

        frame_chuvas = ttk.LabelFrame(
            self.frame_esquerdo,
            text="CHUVAS EFETIVAS",
            padding=7
        )

        frame_chuvas.pack(
            fill="both",
            expand=True
        )

        colunas = (
            "bloco",
            "pm",
            "pe",
            "dpe",
            "q"
        )

        self.tabela_chuvas = ttk.Treeview(
            frame_chuvas,
            columns=colunas,
            show="headings",
            height=6
        )

        self.tabela_chuvas.heading(
            "bloco",
            text="i"
        )

        self.tabela_chuvas.heading(
            "pm",
            text="Pm"
        )

        self.tabela_chuvas.heading(
            "pe",
            text="Pe"
        )

        self.tabela_chuvas.heading(
            "dpe",
            text="dPe"
        )

        self.tabela_chuvas.heading(
            "q",
            text="q cm"
        )

        self.tabela_chuvas.column(
            "bloco",
            width=30,
            anchor="center"
        )

        self.tabela_chuvas.column(
            "pm",
            width=58,
            anchor="center"
        )

        self.tabela_chuvas.column(
            "pe",
            width=58,
            anchor="center"
        )

        self.tabela_chuvas.column(
            "dpe",
            width=58,
            anchor="center"
        )

        self.tabela_chuvas.column(
            "q",
            width=55,
            anchor="center"
        )

        self.tabela_chuvas.pack(
            fill="both",
            expand=True
        )

    def criar_campo(self, texto):

        ttk.Label(
            self.frame_esquerdo,
            text=texto,
            style="Normal.TLabel"
        ).pack(
            anchor="w"
        )

        entry = ttk.Entry(
            self.frame_esquerdo,
            font=("Segoe UI", 11)
        )

        entry.pack(
            fill="x",
            pady=(4, 11)
        )

        return entry

    # ========================================================
    # ABAS DOS GRAFICOS
    # ========================================================

    def criar_abas_graficos(self):

        self.notebook = ttk.Notebook(
            self.frame_direito
        )

        self.notebook.grid(
            row=0,
            column=0,
            sticky="nsew"
        )

        self.aba_hut = ttk.Frame(
            self.notebook
        )

        self.aba_parciais = ttk.Frame(
            self.notebook
        )

        self.aba_projeto = ttk.Frame(
            self.notebook
        )

        self.notebook.add(
            self.aba_hut,
            text="HUT UNITARIO"
        )

        self.notebook.add(
            self.aba_parciais,
            text="HIDROGRAMAS PARCIAIS"
        )

        self.notebook.add(
            self.aba_projeto,
            text="HIDROGRAMA DE PROJETO"
        )

        # Grafico 1
        self.fig_hut = Figure(
            figsize=(9, 5),
            dpi=100
        )

        self.ax_hut = self.fig_hut.add_subplot(
            111
        )

        self.canvas_hut = FigureCanvasTkAgg(
            self.fig_hut,
            master=self.aba_hut
        )

        self.canvas_hut.get_tk_widget().pack(
            fill=tk.BOTH,
            expand=True
        )

        # Grafico 2
        self.fig_parciais = Figure(
            figsize=(9, 5),
            dpi=100
        )

        self.ax_parciais = (
            self.fig_parciais.add_subplot(111)
        )

        self.canvas_parciais = FigureCanvasTkAgg(
            self.fig_parciais,
            master=self.aba_parciais
        )

        self.canvas_parciais.get_tk_widget().pack(
            fill=tk.BOTH,
            expand=True
        )

        # Grafico 3
        self.fig_projeto = Figure(
            figsize=(9, 5),
            dpi=100
        )

        self.ax_projeto = (
            self.fig_projeto.add_subplot(111)
        )

        self.canvas_projeto = FigureCanvasTkAgg(
            self.fig_projeto,
            master=self.aba_projeto
        )

        self.canvas_projeto.get_tk_widget().pack(
            fill=tk.BOTH,
            expand=True
        )

    # ========================================================
    # PAINEL DE RESULTADOS
    # ========================================================

    def criar_resultados(self):

        frame = ttk.Frame(
            self.frame_direito
        )

        frame.grid(
            row=1,
            column=0,
            sticky="ew",
            pady=(10, 0)
        )

        frame.columnconfigure(
            0,
            weight=1
        )

        frame.columnconfigure(
            1,
            weight=1
        )

        # ----------------------------------------------------
        # PARAMETROS HUT
        # ----------------------------------------------------

        frame_hut = ttk.LabelFrame(
            frame,
            text="PARAMETROS DO HUT",
            padding=10
        )

        frame_hut.grid(
            row=0,
            column=0,
            sticky="nsew",
            padx=(0, 5)
        )

        self.labels_resultados = {}

        linhas = [
            ("dt", "Delta t"),
            ("tp", "Tp"),
            ("tr", "Tr"),
            ("tb", "Tb"),
            ("mu", "mu(Tp)")
        ]

        for linha, (
            chave,
            descricao
        ) in enumerate(linhas):

            estilo = (
                "Destaque.TLabel"
                if chave in ("tp", "mu")
                else "Normal.TLabel"
            )

            ttk.Label(
                frame_hut,
                text=descricao,
                style=estilo
            ).grid(
                row=linha,
                column=0,
                sticky="w",
                pady=3
            )

            valor = ttk.Label(
                frame_hut,
                text="--",
                style=estilo
            )

            valor.grid(
                row=linha,
                column=1,
                sticky="w",
                padx=15,
                pady=3
            )

            self.labels_resultados[
                chave
            ] = valor

        # ----------------------------------------------------
        # RESULTADO FINAL
        # ----------------------------------------------------

        frame_final = ttk.LabelFrame(
            frame,
            text="HIDROGRAMA DE PROJETO",
            padding=10
        )

        frame_final.grid(
            row=0,
            column=1,
            sticky="nsew",
            padx=(5, 0)
        )

        ttk.Label(
            frame_final,
            text="Qmax:",
            style="Destaque.TLabel"
        ).grid(
            row=0,
            column=0,
            sticky="w",
            pady=5
        )

        self.label_qmax = ttk.Label(
            frame_final,
            text="--",
            style="Destaque.TLabel"
        )

        self.label_qmax.grid(
            row=0,
            column=1,
            sticky="w",
            padx=15
        )

        ttk.Label(
            frame_final,
            text="Tempo do pico:",
            style="Destaque.TLabel"
        ).grid(
            row=1,
            column=0,
            sticky="w",
            pady=5
        )

        self.label_tqmax = ttk.Label(
            frame_final,
            text="--",
            style="Destaque.TLabel"
        )

        self.label_tqmax.grid(
            row=1,
            column=1,
            sticky="w",
            padx=15
        )

        ttk.Label(
            frame_final,
            text="Chuva efetiva total:",
            style="Normal.TLabel"
        ).grid(
            row=2,
            column=0,
            sticky="w",
            pady=5
        )

        self.label_pe_total = ttk.Label(
            frame_final,
            text="--",
            style="Normal.TLabel"
        )

        self.label_pe_total.grid(
            row=2,
            column=1,
            sticky="w",
            padx=15
        )

    # ========================================================
    # STATUS
    # ========================================================

    def criar_status(self):

        frame = ttk.Frame(
            self,
            padding=(15, 7)
        )

        frame.grid(
            row=1,
            column=0,
            columnspan=2,
            sticky="ew"
        )

        frame.columnconfigure(
            0,
            weight=1
        )

        self.label_status = ttk.Label(
            frame,
            text="Pronto para calcular."
        )

        self.label_status.grid(
            row=0,
            column=0,
            sticky="w"
        )

        ttk.Label(
            frame,
            text=(
                "HUT: m3/s/cm   |   "
                "Hidrograma de projeto: m3/s"
            )
        ).grid(
            row=0,
            column=1,
            sticky="e"
        )

    # ========================================================
    # VALORES INICIAIS
    # ========================================================

    def preencher_valores_iniciais(self):

        self.entry_area.insert(
            0,
            "24.66"
        )

        self.entry_tc.insert(
            0,
            "2.383"
        )

        self.entry_cn.insert(
            0,
            "80"
        )

        self.entry_tr.insert(
            0,
            "100"
        )

        valores = [
            81.30,
            104.75,
            121.77,
            133.84
        ]

        for entry, valor in zip(
            self.entries_prec,
            valores
        ):

            entry.insert(
                0,
                f"{valor:.2f}"
            )

    # ========================================================
    # CALCULO PRINCIPAL
    # ========================================================

    def calcular(self):

        try:

            area = converter_float(
                self.entry_area.get()
            )

            tc = converter_float(
                self.entry_tc.get()
            )

            cn = converter_float(
                self.entry_cn.get()
            )

            tr_anos = converter_float(
                self.entry_tr.get()
            )

            precipitacoes = [
                converter_float(
                    entry.get()
                )
                for entry in self.entries_prec
            ]

            if area <= 0:
                raise ValueError(
                    "Area deve ser maior que zero."
                )

            if tc <= 0:
                raise ValueError(
                    "Tc deve ser maior que zero."
                )

            if not 0 < cn <= 100:
                raise ValueError(
                    "CN deve estar entre 0 e 100."
                )

            if tr_anos <= 0:
                raise ValueError(
                    "TR deve ser maior que zero."
                )

            metodo = selecionar_metodo(
                area,
                tc
            )

            self.label_criterio.config(
                text=metodo["descricao"]
            )

            if metodo["codigo"] != "hut_4_blocos":

                messagebox.showwarning(
                    "Criterio",
                    (
                        metodo["descricao"]
                        + "\n\n"
                        + "Esta versao calcula completamente "
                        + "o caso A > 20 km2 e Tc < 24 h."
                    )
                )

                return

            # -----------------------------------------------
            # HUT
            # -----------------------------------------------

            parametros = calcular_parametros_hut(
                area,
                tc
            )

            self.parametros = parametros

            # -----------------------------------------------
            # CHUVAS
            # -----------------------------------------------

            cr, chuvas = calcular_chuvas(
                area,
                cn,
                precipitacoes
            )

            self.chuvas = chuvas

            # -----------------------------------------------
            # PICO DO RESULTANTE
            # -----------------------------------------------

            tqmax, qmax = encontrar_pico_exato(
                chuvas,
                parametros
            )

            # -----------------------------------------------
            # INTERFACE
            # -----------------------------------------------

            self.atualizar_tempos(
                parametros["dt"]
            )

            self.atualizar_parametros(
                parametros
            )

            self.atualizar_chuvas(
                chuvas
            )

            pe_total = sum(
                chuva["delta_pe_mm"]
                for chuva in chuvas
            )

            self.label_qmax.config(
                text=f"{qmax:.2f} m3/s"
            )

            self.label_tqmax.config(
                text=(
                    f"{tqmax:.3f} h"
                    f"  ({tqmax * 60:.1f} min)"
                )
            )

            self.label_pe_total.config(
                text=f"{pe_total:.2f} mm"
            )

            # -----------------------------------------------
            # GRAFICOS
            # -----------------------------------------------

            self.plotar_hut(
                parametros
            )

            self.plotar_parciais(
                parametros,
                chuvas
            )

            self.plotar_projeto(
                parametros,
                chuvas,
                tqmax,
                qmax
            )

            self.label_status.config(
                text=(
                    "Calculo realizado com sucesso. "
                    f"Qmax = {qmax:.2f} m3/s."
                )
            )

        except ValueError as erro:

            messagebox.showerror(
                "Dados invalidos",
                str(erro)
            )

            self.label_status.config(
                text="Erro nos dados de entrada."
            )

        except Exception as erro:

            messagebox.showerror(
                "Erro",
                str(erro)
            )

    # ========================================================
    # ATUALIZACOES
    # ========================================================

    def atualizar_tempos(self, dt):

        for i, label in enumerate(
            self.labels_tempos,
            start=1
        ):

            tempo = (
                i
                * dt
                * 60.0
            )

            label.config(
                text=f"{tempo:.3f}"
            )

    def atualizar_parametros(
        self,
        p
    ):

        self.labels_resultados[
            "dt"
        ].config(
            text=(
                f"{p['dt']:.6f} h"
                f" ({p['dt'] * 60:.3f} min)"
            )
        )

        self.labels_resultados[
            "tp"
        ].config(
            text=(
                f"{p['tp']:.6f} h"
                f" ({p['tp'] * 60:.3f} min)"
            )
        )

        self.labels_resultados[
            "tr"
        ].config(
            text=(
                f"{p['tr']:.6f} h"
                f" ({p['tr'] * 60:.3f} min)"
            )
        )

        self.labels_resultados[
            "tb"
        ].config(
            text=(
                f"{p['tb']:.6f} h"
                f" ({p['tb'] * 60:.3f} min)"
            )
        )

        self.labels_resultados[
            "mu"
        ].config(
            text=(
                f"{p['mu']:.2f} m3/s/cm"
            )
        )

    def atualizar_chuvas(
        self,
        chuvas
    ):

        for item in (
            self.tabela_chuvas.get_children()
        ):
            self.tabela_chuvas.delete(
                item
            )

        for chuva in chuvas:

            self.tabela_chuvas.insert(
                "",
                "end",
                values=(
                    chuva["bloco"],
                    f"{chuva['pm']:.2f}",
                    f"{chuva['pe']:.2f}",
                    f"{chuva['delta_pe_mm']:.2f}",
                    f"{chuva['q_cm']:.3f}"
                )
            )

    # ========================================================
    # GRAFICO 1 - HUT UNITARIO
    # ========================================================

    def plotar_hut(
        self,
        p
    ):

        ax = self.ax_hut

        ax.clear()

        tempos = np.linspace(
            0,
            p["tb"],
            700
        )

        valores = [
            ordenada_hut(
                t,
                p["tp"],
                p["tr"],
                p["tb"],
                p["mu"]
            )
            for t in tempos
        ]

        ax.plot(
            tempos,
            valores,
            linewidth=2.2,
            label="HUT unitario"
        )

        ax.scatter(
            [
                0,
                p["tp"],
                p["tb"]
            ],
            [
                0,
                p["mu"],
                0
            ],
            s=50,
            zorder=5
        )

        ax.annotate(
            (
                f"Tp = {p['tp']:.3f} h\n"
                f"mu(Tp) = {p['mu']:.2f} m3/s/cm"
            ),
            xy=(
                p["tp"],
                p["mu"]
            ),
            xytext=(
                p["tp"] + 0.25,
                p["mu"] * 1.08
            ),
            fontsize=10,
            fontweight="bold",
            arrowprops={
                "arrowstyle": "->"
            },
            bbox={
                "boxstyle": "round,pad=0.4",
                "facecolor": "white",
                "alpha": 0.95
            }
        )

        ax.set_title(
            "HIDROGRAMA UNITARIO TRIANGULAR - HUT",
            fontweight="bold"
        )

        ax.set_xlabel(
            "Tempo (h)"
        )

        ax.set_ylabel(
            "Vazao unitaria (m3/s/cm)"
        )

        ax.set_xlim(
            0,
            p["tb"] * 1.10
        )

        ax.set_ylim(
            0,
            p["mu"] * 1.30
        )

        ax.grid(
            True,
            linestyle="--",
            alpha=0.35
        )

        ax.legend()

        self.fig_hut.tight_layout()

        self.canvas_hut.draw()

    # ========================================================
    # GRAFICO 2 - HIDROGRAMAS PARCIAIS
    # ========================================================

    def plotar_parciais(
        self,
        p,
        chuvas
    ):

        ax = self.ax_parciais

        ax.clear()

        tempo_final = (
            p["tb"]
            + (len(chuvas) - 1) * p["dt"]
        )

        tempos = np.linspace(
            0,
            tempo_final,
            1200
        )

        for j, chuva in enumerate(
            chuvas
        ):

            deslocamento = (
                j * p["dt"]
            )

            vazoes = [
                vazao_parcial(
                    t,
                    deslocamento,
                    chuva["q_cm"],
                    p
                )
                for t in tempos
            ]

            ax.plot(
                tempos,
                vazoes,
                linewidth=1.8,
                label=(
                    f"q{j + 1} = "
                    f"{chuva['q_cm']:.3f} cm"
                )
            )

        ax.set_title(
            "HIDROGRAMAS PARCIAIS",
            fontweight="bold"
        )

        ax.set_xlabel(
            "Tempo (h)"
        )

        ax.set_ylabel(
            "Vazao (m3/s)"
        )

        ax.set_xlim(
            left=0
        )

        ax.set_ylim(
            bottom=0
        )

        ax.grid(
            True,
            linestyle="--",
            alpha=0.35
        )

        ax.legend()

        self.fig_parciais.tight_layout()

        self.canvas_parciais.draw()

    # ========================================================
    # GRAFICO 3 - HIDROGRAMA RESULTANTE
    # ========================================================

    def plotar_projeto(
        self,
        p,
        chuvas,
        tqmax,
        qmax
    ):

        ax = self.ax_projeto

        ax.clear()

        tempo_final = (
            p["tb"]
            + (len(chuvas) - 1)
            * p["dt"]
        )

        tempos = np.linspace(
            0,
            tempo_final,
            1500
        )

        vazoes = [
            vazao_total(
                t,
                chuvas,
                p
            )
            for t in tempos
        ]

        ax.plot(
            tempos,
            vazoes,
            linewidth=2.5,
            label="Q(t) total"
        )

        ax.scatter(
            [tqmax],
            [qmax],
            s=65,
            zorder=5
        )

        ax.annotate(
            (
                f"t pico = {tqmax:.3f} h\n"
                f"Qmax = {qmax:.2f} m3/s"
            ),
            xy=(
                tqmax,
                qmax
            ),
            xytext=(
                tqmax + 0.35,
                qmax * 1.08
            ),
            fontsize=11,
            fontweight="bold",
            arrowprops={
                "arrowstyle": "->"
            },
            bbox={
                "boxstyle": "round,pad=0.45",
                "facecolor": "white",
                "alpha": 0.95
            }
        )

        ax.set_title(
            "HIDROGRAMA DE PROJETO",
            fontweight="bold"
        )

        ax.set_xlabel(
            "Tempo (h)"
        )

        ax.set_ylabel(
            "Vazao (m3/s)"
        )

        ax.set_xlim(
            0,
            tempo_final * 1.05
        )

        ax.set_ylim(
            0,
            qmax * 1.28
        )

        ax.grid(
            True,
            linestyle="--",
            alpha=0.35
        )

        ax.legend()

        self.fig_projeto.tight_layout()

        self.canvas_projeto.draw()

    # ========================================================
    # LIMPAR
    # ========================================================

    def limpar(self):

        campos = [
            self.entry_area,
            self.entry_tc,
            self.entry_cn,
            self.entry_tr
        ]

        campos.extend(
            self.entries_prec
        )

        for campo in campos:
            campo.delete(
                0,
                tk.END
            )

        for label in self.labels_tempos:
            label.config(
                text="--"
            )

        for label in (
            self.labels_resultados.values()
        ):
            label.config(
                text="--"
            )

        for item in (
            self.tabela_chuvas.get_children()
        ):
            self.tabela_chuvas.delete(
                item
            )

        self.label_qmax.config(
            text="--"
        )

        self.label_tqmax.config(
            text="--"
        )

        self.label_pe_total.config(
            text="--"
        )

        self.label_criterio.config(
            text="--"
        )

        self.ax_hut.clear()
        self.ax_parciais.clear()
        self.ax_projeto.clear()

        self.canvas_hut.draw()
        self.canvas_parciais.draw()
        self.canvas_projeto.draw()

        self.label_status.config(
            text="Campos limpos."
        )


# ============================================================
# EXECUCAO
# ============================================================

if __name__ == "__main__":

    app = AplicacaoHUT()

    app.mainloop()