import json
import requests
import sys
import xlsxwriter

file = open(sys.argv[1], 'r')


def load(file):
    sequences = []
    header = None
    curseq = ''
    for line in file:
        if line.startswith('>'):
            if header and curseq:
                sequences.append({
                    'header': header,
                    'sequence': curseq
                })
            header = line[1:].strip()
            curseq = ''
        elif line.startswith('#'):
            continue
        else:
            curseq += line.strip()
    if header and curseq:
        sequences.append({
            'header': header,
            'sequence': curseq
        })
    return sequences


sequences = {'sequences': load(file)}


resp = requests.post(
    'https://hivdb.stanford.edu/graphql',
    data=json.dumps({
        'query': '''query example($sequences: [UnalignedSequenceInput]!) {
viewer {
    currentVersion { text, publishDate },
    sequenceAnalysis(sequences: $sequences) {
    # Begin of sequenceAnalysis fragment
    inputSequence {
        header,
    },
    validationResults {
        level,
        message
    },
    bestMatchingSubtype { display },
    drugResistance {
        gene {
        name
        },
        drugScores {
        drugClass {
            name,
            fullName,
            drugs {
              name,
              displayAbbr,
              fullName
            }
          },
        drug { displayAbbr, fullName },
        SIR,
        score,
        level,
        text,
        partialScores {
            mutations {
            text
            },
            score
        }
        },
        mutationsByTypes {
        mutationType,
          mutations {
            text,
            shortText
          }
        },
        commentsByTypes {
        commentType,
        comments {
            type,
            text,
            highlightText
        }
        }
    }
    # End of sequenceAnalysis fragment
    }
}
}''',
        'variables': sequences
    }),
    headers={
        'Content-Type': 'application/json'
    }
)

alldata = resp.json()['data']['viewer']['sequenceAnalysis']
allgenes = []
drugs = {}
genename = {
    "HIV-1 törzsek gyógyszerrezisztenciájának meghatározása genomikus szekvenálással": ""}
geneitem = {}
muttypes = {}
for data in alldata:
    general = {
        "header": data['inputSequence']['header'],
        "best matching subtype": data['bestMatchingSubtype']['display']
    }
    for index, gene in enumerate(data['drugResistance']):
        isRTI = False
        for index, drug in enumerate(gene['drugScores']):
            if genename["HIV-1 törzsek gyógyszerrezisztenciájának meghatározása genomikus szekvenálással"] != drug['drugClass']['name']:
                geneitem.update(genename)
                geneitem.update(muttypes)
                geneitem.update(drugs)
                allgenes.append(geneitem)
                drugs = {}
                geneitem = {}
                druginfo = {}
                muttypes = {}

                for index, mutypes in enumerate(gene['mutationsByTypes']):
                    if mutypes['mutationType'] == drug['drugClass']['name']:
                        isRTI = True
                        mutstr = ''
                        for mut in mutypes['mutations']:
                            mutstr = mutstr + mut['text'] + ', '
                        if mutstr == '':
                            mutstr = 'nincs  '
                        muttypes.update(
                            {mutypes['mutationType']: mutstr[:len(mutstr)-2]})
                genename = {
                    "HIV-1 törzsek gyógyszerrezisztenciájának meghatározása genomikus szekvenálással": drug['drugClass']['name']}

            druginfo = {drug['drug']['fullName'] +
                        " (" + drug['drug']['displayAbbr'] + ")": drug['text']}
            drugs.update(druginfo)
        if not isRTI:
            for index, mutypes in enumerate(gene['mutationsByTypes']):
                mutstr = ''
                if mutypes['mutationType'] != 'Other':
                    for mut in mutypes['mutations']:
                        mutstr = mutstr + mut['text'] + ', '
                    if mutstr == '':
                        mutstr = 'nincs  '
                    muttypes.update(
                        {gene['gene']['name'] + mutypes['mutationType']: mutstr[:len(mutstr)-2]})
geneitem.update(genename)
geneitem.update(muttypes)
geneitem.update(drugs)
allgenes.append(geneitem)

allgenes = allgenes[1:]
workbook = xlsxwriter.Workbook(sys.argv[2])
worksheet = workbook.add_worksheet()

worksheet.set_column('A:A', 40)
worksheet.set_column('B:D', 30)


bold = workbook.add_format({'bold': True, 'text_wrap': True, 'valign': 'top'})
text = workbook.add_format({'text_wrap': True, 'valign': 'top'})

worksheet.write('A1', 'Megnevezés', bold)
worksheet.write('B1', 'Eredmény', bold)
worksheet.write('C1', 'Minősítés', bold)
worksheet.write('D1', 'Vélemény', bold)

firstColumnDict = {
    'PRMajor': 'PI elsődleges mutációk:',
    'PRAccessory': 'PI másodlagos mutációk:',
    'INMajor': 'INI elsődleges mutációk:',
    'INAccessory': 'INI másodlagos mutációk:',
    'NNRTI': 'NNRTI mutációk',
    'NRTI': 'NRTI mutációk',
}
secondColumnDict = {
    'PI': 'Proteáz inhibitorok (PI)',
    'NNRTI': 'Nukleozid reverz transzkriptáz inhibitorok (NRTI)',
    'NRTI': 'Nem nukleozid reverz transzkriptáz inhibitorok (NNRTI)',
    'INSTI': 'Integráz inhibitorok (INI)',
    'Susceptible': 'nem rezisztens',
    'Low-Level Resistance': 'alacsony fokú rezisztencia',
    'Intermediate Resistance': 'mérsékelt rezisztencia',
    'High-Level Resistance': 'magas fokú rezisztencia'
}
row = 2
for index, drugClass in enumerate(allgenes):
    for index, a in enumerate(list(drugClass.keys())):
        if index == 0:
            worksheet.write('A' + str(row), a, bold)
        elif index > 0 and a not in firstColumnDict.keys():
            worksheet.write('A' + str(row), a, text)
        else:
            worksheet.write('A' + str(row), firstColumnDict[a], text)
        row = row + 1

row = 2
for index, drugClass in enumerate(allgenes):
    for index, a in enumerate(list(drugClass.values())):
        if index == 0:
            worksheet.write('B' + str(row), secondColumnDict[a], bold)
        elif index > 0 and a not in secondColumnDict.keys():
            worksheet.write('B' + str(row), a, text)
        else:
            worksheet.write('B' + str(row), secondColumnDict[a], text)
        row = row + 1


workbook.close()
