When Waste Pays: replication package
====================================

This repository holds the data and Stata code for "When Waste Pays:
Zero-Waste Cities, Circular Value Capture, and Firm Green Productivity",
submitted to Energy Economics. A single do-file, run from top to bottom on
the dataset supplied here, reproduces every estimate in Tables 1-12 and
Figures 1-5.


Files
-----

replication_data.dta
    Firm-year panel of Chinese A-share listed firms, 2010-2023, with 36,010
    observations on 96 variables. Variable names and labels are in English.
    Where the paper denotes a variable by a symbol, the label begins with it
    ("GP:", "Zerocity:", "CEB:" and so on).

replication.do
    The full analysis, organized in the order shown under "Where each result
    is produced".

README.md, README.txt
    This guide in Markdown and in plain text.

In the code, the outcome GP is gp and the treatment indicator Zerocity is
did.


Software
--------

The results were produced with Stata/MP 19.5 (StataNow). The do-file calls
the following user-written packages:

    ssc install ftools
    ssc install reghdfe
    ssc install estout
    ssc install outreg2
    ssc install logout
    ssc install coefplot
    ssc install didplacebo, all replace
    ssc install twowayfeweights
    ssc install did_imputation
    ssc install event_plot
    ssc install psmatch2
    ssc install bdiffv
    ssc install ddml
    ssc install pystacked
    net install ddtiming, from(https://raw.githubusercontent.com/tgoldring/ddtiming/master)

The double/debiased machine learning (DML) estimates in Table 6 run
scikit-learn through Stata's Python integration (help python), so they also
require a Python installation with scikit-learn. The interactive model in
Table 6, column (5), was estimated with ddml 1.4.4, pystacked 0.8.0, Python
3.11.9 and scikit-learn 1.9.1; other versions can move machine-learning
estimates slightly.

On Windows, Stata/MP stops with "OMP: Error #15" when it is pointed to an
Anaconda Python, whose NumPy is built against Intel MKL. A python.org
installation with scikit-learn installed through pip avoids the problem.
Select it before running the DML section:

    set python_exec "path\to\python.exe"


Running the code
----------------

1. At the top of replication.do, set global data to the location of
   replication_data.dta and cd to the folder that will receive the output.
2. Run the do-file from top to bottom.

Tables are saved as RTF, Excel and text files, and figures as PNG and Stata
.gph files. The period-by-period matching step also writes one matched
sample per year, 2010.dta to 2023.dta. Excluding the DML section, a full run
takes about 30 minutes on a desktop PC with Stata/MP 19.5. The interactive
DML model alone took about another 30 minutes.

Code comments are in Chinese with English translations. Several output files
have Chinese names; the header of replication.do gives their English meaning
and the table each one feeds. The do-file is encoded in UTF-8, which Stata
14 and later read without conversion.


Where each result is produced
-----------------------------

Sections of replication.do, in the order they run:

  Descriptive statistics (tabstat, logout)              Table 1
  Average annual change in GP across all firms since    Section 4.1,
    2019 (collapse)                                     0.0269 per year
  Baseline regressions (m1-m3)                          Table 2
  Event study (coefplot)                                Figure 1
  Double/debiased machine learning (ddml, pystacked)    Table 6
  Spatial and mixed placebo tests (didplacebo)          Figures 2 and 3
  Macro-level confounders and competing policies        Table 3
  Heterogeneous treatment effects: Goodman-Bacon        Table 5
    decomposition (ddtiming) and de Chaisemartin-
    D'Haultfoeuille weights (twowayfeweights)
  Imputation estimator of Borusyak et al.               Figure 4
    (did_imputation, event_plot)
  PSM-DID with nearest-neighbor, kernel and             Table 4
    period-by-period matching (psmatch2)
  Green patents                                         Table 9
  Solid-waste patents by waste stream and industry      Table 10
  Green capital investment                              Table 11
  Circular value capture                                Table 12
  Heterogeneity, with between-group tests (bdiffv)      Table 7
  Global efficiency change and global technical change  Table 8 and
                                                        Figure 5

Only one appendix table reports estimates. Tables A.1, B.1, C.1, D.1 and E.2
are keyword dictionaries and an industry classification: the measures built
with the dictionaries in Tables A.1, B.1 and D.1 are stored in the dataset,
and the classification in Table C.1 is also coded in replication.do.
Appendix Table E.1, the exception, uses city-level regulation measures (ER1
and ER2, built with the dictionary in Table E.2) that are not part of this
package, so the do-file does not produce it.


Data sources and access
-----------------------

Firm financial, operating and governance variables come from the China Stock
Market & Accounting Research (CSMAR) database. Environmental performance,
green investment and green innovation draw on the Chinese Research Data
Services (CNRDS) platform, listed firms' annual reports and the patent
database of the China National Intellectual Property Administration. City
characteristics are taken from the China Energy Statistical Yearbook, the
China Environmental Statistics Yearbook and the China City Statistical
Yearbook. Treatment status follows the zero-waste-city pilot lists of the
Ministry of Ecology and Environment and the construction plans issued by
provincial and city governments.

replication_data.dta contains the analysis variables built from these
sources, so reproducing the results requires no database access. CSMAR
(https://data.csmar.com) and CNRDS (https://www.cnrds.com) are commercial
databases; rebuilding the variables from their raw records requires a
subscription from each provider. The yearbooks, annual reports, patent
records and policy documents are published sources.


Notes on specific results
-------------------------

Random seeds are fixed in the code: 6 for the spatial placebo test, 3 for
the mixed placebo test, 10101 for propensity-score matching, 42 for DML, and
3, 26 and 3 for the three bdiffv tests (growth competition, network
embeddedness and policy approach, in the order they run).

Five variables enter the analysis as stored: greenbuy (GPA), pa (PA), ceb
(CEB), opm (OPM) and group_pre2019. These are the versions used in the
paper, and the do-file does not rebuild them.

In Table 7, columns (1) and (2) split firms by the stored indicator
group_pre2019; columns (3) to (6) split firm-years at the sample median of
the annual measure (xtile, nq(2)). The between-group p-values come from the
Fisher permutation test in bdiffv with 500 replications, run on the same
specification as the Table 7 regressions, with standard errors clustered by
city.

In the interactive DML model (Table 6, column 5), size is already the log of
total assets and enters the controls as it is, together with its square.
With the versions listed under Software, the model returns 0.0790 (standard
error 0.0009).
