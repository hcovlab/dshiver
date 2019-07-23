import json
import requests
import sys
import xlsxwriter
from requests.exceptions import ConnectionError
import time

# Create English-Hungarian dictionary in order to translate the results
firstColumnDict = {
    'PRMajor': 'PI elsődleges mutációk:',
    'PRAccessory': 'PI másodlagos mutációk:',
    'INMajor': 'INI elsődleges mutációk:',
    'INAccessory': 'INI másodlagos mutációk:',
    'NNRTI': 'NNRTI mutációk',
    'NRTI': 'NRTI mutációk',
    'Drug Class Name': 'HIV-1 törzsek gyógyszerrezisztenciájának meghatározása genomikus szekvenálással'
}
secondColumnDict = {
    'PI': 'Proteáz inhibitorok (PI)',
    'NNRTI': 'Nukleozid reverz transzkriptáz inhibitorok (NRTI)',
    'NRTI': 'Nem nukleozid reverz transzkriptáz inhibitorok (NNRTI)',
    'INSTI': 'Integráz inhibitorok (INI)',
    'Susceptible': 'nem rezisztens',
    'Low-Level Resistance': 'kis mértékű rezisztencia',
    'Intermediate Resistance': 'közepes szintű rezisztencia',
    'High-Level Resistance': 'nagy mértékű rezisztencia',
    '': 'nincs'
}
# Formulate query
query = '''query example($sequences: [UnalignedSequenceInput]!) {
        viewer {
            currentVersion { text, publishDate },
            sequenceAnalysis(sequences: $sequences) {
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
            }
        }
        }'''


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


def request(file):
    sequences = {'sequences': load(file)}
    resp = requests.post(
        'https://hivdb.stanford.edu/graphql',
        data=json.dumps({
            'query': query,
            'variables': sequences
        }),
        headers={
            'Content-Type': 'application/json'
        }
    )
    return resp


def parseData(alldata):
    mutations = [], []
    drugClassName, mutationtype = '', ''
    firstCol, secondCol, drugClassNames, resistances = [], [], [], []

    for data in alldata:
        for gene in data['drugResistance']:
            isRTI = False
            for drug in gene['drugScores']:
                if drugClassName != drug['drugClass']['name']:
                    firstCol.append(
                        ['Drug Class Name', mutationtype] + drugClassNames)
                    secondCol.append(
                        [drugClassName] + [', '.join(map(str, mutations))] + resistances)

                    drugClassNames = []
                    resistances = []

                    for mutationtypes in gene['mutationsByTypes']:
                        if mutationtypes['mutationType'] == drug['drugClass']['name']:
                            isRTI = True
                            mutations = []
                            for mutation in mutationtypes['mutations']:
                                mutations.append(mutation['text'])
                            mutationtype = mutationtypes['mutationType']
                    drugClassName = drug['drugClass']['name']

                drugClassNames.append(
                    drug['drug']['fullName'] + ' (' + drug['drug']['displayAbbr'] + ')')
                resistances.append(drug['text'])

            if not isRTI:
                for mutationtypes in gene['mutationsByTypes']:
                    mutations = []
                    if mutationtypes['mutationType'] != 'Other':
                        for mutation in mutationtypes['mutations']:
                            mutations.append(mutation['text'])
                        mutationtype = gene['gene']['name'] + \
                            mutationtypes['mutationType']

    firstCol.append(['Drug Class Name', mutationtype] + drugClassNames)
    secondCol.append([drugClassName] +
                     [', '.join(map(str, mutations))] + resistances)

    firstCol = firstCol[1:]
    secondCol = secondCol[1:]

    return firstCol, secondCol


def writexlsx(firstCol, secondCol, file):

    workbook = xlsxwriter.Workbook(file)
    worksheet = workbook.add_worksheet()

    worksheet.set_column('A:A', 40)
    worksheet.set_column('B:D', 30)

    bold = workbook.add_format(
        {'bold': True, 'text_wrap': True, 'valign': 'top'})
    text = workbook.add_format({'text_wrap': True, 'valign': 'top'})

    worksheet.write('A1', 'Megnevezés', bold)
    worksheet.write('B1', 'Eredmény', bold)
    worksheet.write('C1', 'Minősítés', bold)
    worksheet.write('D1', 'Vélemény', bold)

    row = 2
    for index, drugClass in enumerate(firstCol):
        for index, a in enumerate(drugClass):
            if index == 0 and a not in firstColumnDict.keys():
                worksheet.write('A' + str(row), a, bold)
            if index == 0:
                worksheet.write('A' + str(row), firstColumnDict[a], bold)
            elif index > 0 and a not in firstColumnDict.keys():
                worksheet.write('A' + str(row), a, text)
            else:
                worksheet.write('A' + str(row), firstColumnDict[a], text)
            row = row + 1

    row = 2
    for index, drugClass in enumerate(secondCol):
        for index, a in enumerate(drugClass):
            if index == 0:
                worksheet.write('B' + str(row), secondColumnDict[a], bold)
            elif index > 0 and a not in secondColumnDict.keys():
                worksheet.write('B' + str(row), a, text)
            else:
                worksheet.write('B' + str(row), secondColumnDict[a], text)
            row = row + 1

    workbook.close()


try:
    file = open(sys.argv[1], 'r')
except FileNotFoundError:
    print("File not found.")
else:
    i = 1
    while True and i < 6:
        try:
            resp = request(file)
        except ConnectionError:
            print("Iteration " + str(i) + " failed due to connection error.")
            i = i + 1
            time.sleep(10)
        else:
            try:
                alldata = resp.json()['data']['viewer']['sequenceAnalysis']
                firstCol, secondCol = parseData(alldata)

            except TypeError:
                if alldata != []:
                    if alldata[0]['validationResults'] != []:
                        for error in alldata[0]['validationResults']:
                            print(
                                'Error Level: ' + error['level'] + ', Error Message: ' + error['message'])
                else:
                    print("Empty file")

            else:
                try:
                    writexlsx(firstCol, secondCol, sys.argv[2])
                except PermissionError:
                    print("Couldn't write XLSX file due to permission error.")
            break
