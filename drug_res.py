import json
import requests
import sys
import xlsxwriter
from requests.exceptions import ConnectionError
import time
import datetime
import re
import os
import fnmatch

# Check if output file path is provided
if len(sys.argv) < 3:
    print("Usage: python script.py input.fasta output.xlsx")
    sys.exit(1)

input_file = sys.argv[1]
print(f"Input file: '{input_file}'")
output_file = sys.argv[2]
print(f"Output file '{output_file}'")

# Check if output file directory exists and is writable
output_dir = os.path.dirname(output_file)
if not os.path.exists(output_dir) or not os.access(output_dir, os.W_OK):
    print(f"Error: Output directory '{output_dir}' is not writable.")
    sys.exit(1)

# Check if input file exists
if not os.path.exists(input_file):
    print(f"Error: Input file '{input_file}' not found.")
    sys.exit(1)



#lang = sys.argv[3]
lang = 'en'

# Create English-Hungarian dictionary in order to translate the results
firstColumnDict = {'hu':{
    'PRMajor': 'PI elsődleges mutációk:',
    'PRAccessory': 'PI másodlagos mutációk:',
    'PROther': 'PI egyéb potenciális hatású mutációk',
    'INMajor': 'INI elsődleges mutációk:',
    'INAccessory': 'INI másodlagos mutációk:',
    'INOther': 'INI egyéb potenciális hatású mutációk',
    'NNRTI': 'NNRTI mutációk',
    'NRTI': 'NRTI mutációk',
    'Drug Class Name': 'HIV-1 törzsek gyógyszerrezisztenciájának meghatározása genomikus szekvenálással',
    'Other': 'Egyéb',
    'no comments' : 'nincs megjegyzés'
},
                   'en':{
    'PRMajor': 'PI Major Mutations:',
    'PRAccessory': 'PI Accessory Mutations:',
    'PROther': 'PI Other Mutations',
    'INMajor': 'INI Major Mutations:',
    'INAccessory': 'INI Accessory Mutations:',
    'INOther': 'INI Other Mutations',
    'NNRTI': 'NNRTI Mutations',
    'NRTI': 'NRTI Mutations',
    'Drug Class Name': 'HIV-1 drug-resistance mutation testing Sanger sequencing'
}
                   }
secondColumnDict = {'hu':{
    'PI': 'Proteáz inhibitorok (PI)',
    'NNRTI': 'Nem nukleozid reverz transzkriptáz inhibitorok (NNRTI)',
    'NRTI': 'Nukleozid reverz transzkriptáz inhibitorok (NRTI)',
    'INSTI': 'Integráz inhibitorok (INI)',
    'Susceptible': 'nem rezisztens',
    'Low-Level Resistance': 'kis mértékű rezisztencia',
    'Intermediate Resistance': 'közepes szintű rezisztencia',
    'High-Level Resistance': 'nagy mértékű rezisztencia',
    'Other Reverse Transcriptase (RT) Mutations' : 'Egyéb potenciális hatású reverz transzkriptáz mutációk',
    '': 'nincs',
    'no comments' : 'nincs megjegyzés'},
    'en':{
    'PI': 'Protease Inhibitors (PI)',
    'NNRTI': 'Non-nucleoside Reverse Transcriptase Inhibitors (NNRTI)',
    'NRTI': 'Nucleoside Reverse Transcriptase Inhibitors(NRTI)',
    'INSTI': 'Integrase inhibitors (INI)',
    'Susceptible': 'Susceptible',
    'Low-Level Resistance': 'Low-Level Resistance',
    'Intermediate Resistance': 'Intermediate Resistance',
    'High-Level Resistance': 'High-Level Resistance',
    'Other Reverse Transcriptase (RT) Mutations' : 'Other Reverse Transcriptase (RT) Mutations',
    '': 'no mutations'}
}

firstColumnDict = firstColumnDict[lang]
secondColumnDict = secondColumnDict[lang]

class DrugClass:
  def __init__(self, name, mutations, drugs, comments):
    self.name = name
    self.mutations = mutations
    self.drugs = drugs
    self.comments = comments
    
# Formulate query
query = '''query example($sequences: [UnalignedSequenceInput]!) {
        viewer {
            currentVersion { text, publishDate },
            sequenceAnalysis(sequences: $sequences) {
            inputSequence {
                header,
                sequence
            },
            strain { name },
	    subtypeText,
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

def flatten(xss):
    return [x for xs in xss for x in xs]

def parseData(alldata):
#Initiate variables
    drugClassName, mutationtype = '', ''
    class_objects, mutations, errors, firstCol, secondCol,drugClassNames, resistances, mutations_by_types, mutationtype_names = [], [], [], [],[],[], [], [],[]
    mutations_dict, drugResistances, mutationComment = {},{}, {}
#Get database version and subtype
#   input_header = sys.argv[1]
    database = alldata['currentVersion']['text'] + ' ' + alldata['currentVersion']['publishDate']
    subtype = alldata['sequenceAnalysis'][0]['subtypeText']
#Get error messages
    for error in alldata['sequenceAnalysis'][0]['validationResults']:
      errors.append(error['level'] + ', Message: ' + error['message'])
    errors = ' '.join(map(str,errors))
#Drug resistance mutation analysis
    alldata = alldata['sequenceAnalysis']
    for data in alldata:
#Parse through genes
        for gene in data['drugResistance']:
            mutations_dict, drugResistances, mutationComment = {},{},{}
#Parse through the data of non-RT genes            
            if gene['gene']['name'] != 'RT':
                for drug in gene['drugScores']:
                    drugClassName = drug['drugClass']['name']
                    drugName = drug['drug']['fullName'] + ' (' + drug['drug']['displayAbbr'] + ')'
                    drugResistances[drugName] = drug['text']

                for mutationtypes in gene['mutationsByTypes']:
                    mutations = []
                    for mutation in mutationtypes['mutations']:
                        mutations.append(mutation['text'])
                    mutationtype = gene['gene']['name'] + mutationtypes['mutationType']
                    mutations_dict[mutationtype] = ','.join(map(str,mutations))
                    
                for commenttypes in gene['commentsByTypes']:
                    for comment in commenttypes['comments']:
                        mutationComment[comment['highlightText'][0]] = comment['text']
                mutations = set(mutationComment.keys()).intersection(set(mutations_dict[gene['gene']['name'] + 'Other'].split(',')))
                mutations_dict[gene['gene']['name'] + 'Other'] = ', '.join(map(str,list(mutations)))

                if len(list(mutationComment.values())) == 0:
                  class_objects.append(DrugClass(drugClassName, mutations_dict, drugResistances, 'no comments'))
                else:
                  class_objects.append(DrugClass(drugClassName, mutations_dict, drugResistances, ' '.join(map(str,list(mutationComment.values())))))

#Parse through the data of the RT sequence                         
            if gene['gene']['name'] == 'RT':
                for mutationtypes in gene['mutationsByTypes']:
                    mutations = []
                    mutations_dict, drugResistances, mutationComment = {},{},{}
                    for mutation in mutationtypes['mutations']:
                        mutations.append(mutation['text'])
                    mutationtype = mutationtypes['mutationType']
                  
                    mutations_dict[mutationtype] = ','.join(map(str,mutations))
                        
                    for drug in gene['drugScores']:
                        if mutationtype == drug['drugClass']['name']:
                            drugName = drug['drug']['fullName'] + ' (' + drug['drug']['displayAbbr'] + ')'
                            drugResistances[drugName] = drug['text']

                    for commenttypes in gene['commentsByTypes']:
                      for comment in commenttypes['comments']:
                        if comment['type'] == mutationtype:
                          mutationComment[comment['highlightText'][0]] = comment['text']
                          
                    if mutationtype == 'Other':
                        mutations = set(mutationComment.keys()).intersection(set(mutations))
                        mutations_dict[mutationtype] = ','.join(map(str,mutations))
                        if len(list(mutationComment.values())) == 0:
                          class_objects.append(DrugClass('Other Reverse Transcriptase (RT) Mutations', mutations_dict, drugResistances, 'no comments'))
                        else:
                          class_objects.append(DrugClass('Other Reverse Transcriptase (RT) Mutations', mutations_dict, drugResistances, ' '.join(map(str,list(mutationComment.values())))))
                    else:
                      if len(list(mutationComment.values())) == 0:
                        class_objects.append(DrugClass(mutationtype, mutations_dict, drugResistances, 'no comments'))
                      else:
                        class_objects.append(DrugClass(mutationtype, mutations_dict, drugResistances, ' '.join(map(str,list(mutationComment.values())))))
                  
#Set columns
    for obj in class_objects:
      if obj.name == 'Other':
        firstCol.append(list(obj.mutations.keys()) + list(obj.drugs.keys()) + [obj.comments])
        secondCol.append(list(obj.mutations.values()) + list(obj.drugs.values()) + [obj.comments])
      else:
        firstCol.append(['Drug Class Name'] + list(obj.mutations.keys()) + list(obj.drugs.keys()) + [obj.comments])
        secondCol.append([obj.name] + list(obj.mutations.values()) + list(obj.drugs.values()) + [obj.comments])

    return firstCol, secondCol, database, subtype,errors

#Write xlsx file
def writexlsx(firstCol, secondCol,database, subtype,errors, file):
    x = datetime.datetime.now()

    workbook = xlsxwriter.Workbook(file)
    worksheet = workbook.add_worksheet()

    worksheet.set_column('A:A', 60)
    worksheet.set_column('B:B', 60, None, {'level': 1})

    bold = workbook.add_format(
        {'bold': True, 'text_wrap': True, 'valign': 'top'})
    text = workbook.add_format({'valign': 'top'})
    text.set_text_wrap()

    if lang == 'en':
        worksheet.merge_range('A1:B1', 'Query date: '+ x.strftime("%c"), bold)
        worksheet.merge_range('A2:B2', 'Database version: '+ database, bold)
        worksheet.merge_range('A3:B3', 'Sequence name: '+ input_file.split('/')[-1], bold)
        worksheet.merge_range('A4:B4', 'HIV-1 subtype: '+ subtype, bold)
        worksheet.merge_range('A5:B5', errors, bold)
       
        worksheet.write('A6', 'Name', bold)
        worksheet.write('B6', 'Result', bold)
    else:
        worksheet.merge_range('A1:B1', 'Dátum: '+ x.strftime("%c"), bold)
        worksheet.merge_range('A2:B2', 'Adatbázis verzió: '+ database, bold)
        worksheet.merge_range('A3:B3', 'Szekvencia : '+ input_file.split('/')[-1], bold)
        worksheet.merge_range('A4:B4', 'HIV-1 altípus: '+ subtype, bold)
        worksheet.merge_range('A5:B5', errors, bold)
       
        worksheet.write('A6', 'Vizsgálat', bold)
        worksheet.write('B6', 'Eredmény', bold)
 


    row = 7

        
   
    for index, drugClass in enumerate(firstCol):
        for index, a in enumerate(drugClass):
            if index > 0 and index < (len(drugClass) - 1) and a not in firstColumnDict.keys():
                worksheet.write('A' + str(row), a, text)
            elif index > 0 and index < (len(drugClass) - 1):
                worksheet.write('A' + str(row), firstColumnDict[a], text)
            row = row + 1

    row = 7
    for index, drugClass in enumerate(secondCol):
        for index, a in enumerate(drugClass):
            if index == 0 and a not in secondColumnDict.keys():
                worksheet.merge_range('A' + str(row) + ':B' + str(row), a, bold)
            elif index == 0 and a == 'Other Reverse Transcriptase (RT) Mutations':
                worksheet.merge_range('A' + str(row) + ':B' + str(row), secondColumnDict[a], text)
            elif index == 0:
                worksheet.merge_range('A' + str(row) + ':B' + str(row), secondColumnDict[a], bold)
            elif index > 0 and index < (len(drugClass) - 1) and a not in secondColumnDict.keys():
                worksheet.write('B' + str(row), a, text)
            elif index > 0 and index < (len(drugClass) - 1):
                worksheet.write('B' + str(row), secondColumnDict[a], text)
            else:
                worksheet.merge_range('A' + str(row) + ':B' + str(row), a, text)
            row = row + 1

    workbook.close()


try:
#^(?=.*consensus_MinCov)(?!.*ForGlobalAln)(?!.*remap).*
    #file = open(sys.argv[1], 'r')
    f = 'consenus_placeholder'
    pattern = r"^(?=.*consensus_MinCov)(?!.*ForGlobalAln)(?!.*remap).*"
    
    
    for getfile in os.listdir('/data/'):
        if 'consensus_MinCov' in getfile and 'ForGlobalAln' not in getfile:
            f = '/data/' + getfile
 
    file = open(f, 'r')
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
                alldata = resp.json()['data']['viewer']
                firstCol, secondCol, database, subtype, errors = parseData(alldata)

            except TypeError:
                if alldata != []:
                    if alldata['sequenceAnalysis'][0]['validationResults'] != []:
                        for error in alldata['sequenceAnalysis'][0]['validationResults']:
                            print(
                                'Error Level: ' + error['level'] + ', Error Message: ' + error['message'])
                else:
                    print("Empty file")

            else:
                try:
                    # Write results to the output Excel file
                    writexlsx(firstCol, secondCol, database, subtype, errors, output_file)
                    print("XLSX report successfully written.")
                except PermissionError:
                    print("Error: Permission denied. Couldn't write XLSX file.")
                except Exception as e:
                    print(f"An error occurred: {str(e)}")
            break