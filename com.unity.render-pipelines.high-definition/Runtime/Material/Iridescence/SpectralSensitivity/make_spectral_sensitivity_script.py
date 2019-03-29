import numpy as np

np.set_printoptions(threshold=np.inf)

def ReplaceStrings(template, replace_strings):
    for old, new in replace_strings.items():
        template = template.replace(old, new)
    return template

def Array2String(array):
    return np.array2string(array, prefix='', max_line_width=120, separator=',', formatter={'float': lambda x: '%ff' % x })[1:-1]

NAME = 'Gauss'

sensitivity_filename = 'sensitivity.txt'
template_filename = 'SpectralSensitivityDataNAME.cs.template'
output_filename = 'SpectralSensitivityData' + NAME + '.cs'

with open(sensitivity_filename, 'r') as sensitivity_file, open(template_filename, 'r') as template_file, open(output_filename, 'w') as output_file:

    # Read sensitivity data
    header = sensitivity_file.readline()
    SIGMA_COUNT, SIGMA_MAX, MU_COUNT, MU_MAX = np.fromstring(header, dtype=float, sep=' ')
    SIGMA_COUNT = int(SIGMA_COUNT)
    MU_COUNT = int(MU_COUNT)

    RMAG_DATA = np.zeros(SIGMA_COUNT*MU_COUNT)
    RPHI_DATA = np.zeros(SIGMA_COUNT*MU_COUNT)
    GMAG_DATA = np.zeros(SIGMA_COUNT*MU_COUNT)
    GPHI_DATA = np.zeros(SIGMA_COUNT*MU_COUNT)
    BMAG_DATA = np.zeros(SIGMA_COUNT*MU_COUNT)
    BPHI_DATA = np.zeros(SIGMA_COUNT*MU_COUNT)

    for i in range(SIGMA_COUNT*MU_COUNT):
        line = sensitivity_file.readline()
        data = np.fromstring(line, dtype=float, sep=' ')
        RMAG_DATA[i] = data[0]
        RPHI_DATA[i] = data[1]
        GMAG_DATA[i] = data[2]
        GPHI_DATA[i] = data[3]
        BMAG_DATA[i] = data[4]
        BPHI_DATA[i] = data[5]

    replace_strings = dict()
    replace_strings['NAME'] = NAME
    replace_strings['SIGMA_COUNT'] = str(SIGMA_COUNT)
    replace_strings['SIGMA_MAX'] = str(SIGMA_MAX) + 'f'
    replace_strings['MU_COUNT'] = str(MU_COUNT)
    replace_strings['MU_MAX'] = str(MU_MAX) + 'f'

    replace_strings['RMAG_DATA'] = Array2String(RMAG_DATA)
    replace_strings['RPHI_DATA'] = Array2String(RPHI_DATA)
    replace_strings['GMAG_DATA'] = Array2String(GMAG_DATA)
    replace_strings['GPHI_DATA'] = Array2String(GPHI_DATA)
    replace_strings['BMAG_DATA'] = Array2String(BMAG_DATA)
    replace_strings['BPHI_DATA'] = Array2String(BPHI_DATA)

    template = template_file.read()
    output_file.write(ReplaceStrings(template, replace_strings))
