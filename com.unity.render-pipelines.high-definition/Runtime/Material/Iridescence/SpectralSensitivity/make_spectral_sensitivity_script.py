import numpy as np

np.set_printoptions(threshold=np.inf)

def ReplaceStrings(template, replace_strings):
    for old, new in replace_strings.items():
        template = template.replace(old, new)
    return template

def Array2String(array):
    return np.array2string(array, prefix='', max_line_width=120, separator=',', formatter={'float': lambda x: '%ff' % x })[1:-1]

NAME = 'SRGB'

template_filename = 'SpectralSensitivityDataNAME.cs.template'
output_filename = 'SpectralSensitivityData' + NAME + '.cs'


wavelength,X,Y,Z = np.genfromtxt('raw_data/cie-1931-xyz.csv', delimiter=',', unpack=True, skip_header=1)
wavelength /= 1000 # nanometer to micrometer

CIEXYZ2SRGB = np.matrix([
    [ 3.2406, -1.5372, -0.4986],
    [-0.9489,  1.8758,  0.0415],
    [ 0.0557, -0.2040,  1.0570]])

CIEXYZ = np.matrix([X, Y, Z])
SRGB = CIEXYZ2SRGB * CIEXYZ
SRGB = np.asarray(SRGB)

R = np.squeeze(SRGB[0])
G = np.squeeze(SRGB[1])
B = np.squeeze(SRGB[2])

# normalize sensitivity function
R /= np.sum(R)
G /= np.sum(G)
B /= np.sum(B)

with open(template_filename, 'r') as template_file, open(output_filename, 'w') as output_file:

    # Read sensitivity data
    WAVELENGTH_MIN = wavelength[0]
    WAVELENGTH_MAX = wavelength[-1]
    SAMPLE_COUNT = wavelength.shape[0]

    R_DATA = R
    G_DATA = G
    B_DATA = B

    replace_strings = dict()
    replace_strings['NAME'] = NAME
    replace_strings['SAMPLE_COUNT'] = str(SAMPLE_COUNT)
    replace_strings['WAVELENGTH_MAX'] = str(WAVELENGTH_MAX) + 'f'
    replace_strings['WAVELENGTH_MIN'] = str(WAVELENGTH_MIN) + 'f'

    replace_strings['R_DATA'] = Array2String(R_DATA)
    replace_strings['G_DATA'] = Array2String(G_DATA)
    replace_strings['B_DATA'] = Array2String(B_DATA)

    template = template_file.read()
    output_file.write(ReplaceStrings(template, replace_strings))
