import math
from PIL import Image
import cv2
import matplotlib.pyplot as plt
import numpy
from numpy import array
from numpy import shape
import random
from numpy.linalg import det
from numpy.linalg import inv
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D
from matplotlib import cm
from matplotlib.ticker import LinearLocator, FormatStrFormatter
from skimage import morphology,draw

def read_file(file_path):
    my_file = open(file_path)
    my_mat = numpy.zeros((2160,2160))
    index = 0
    for line in my_file.readlines():
        if (0 < index <= 2160):
            line_list = line.split(' ')
            line_list.pop(-1)
            for some_str in line_list:
                some_str.replace('U00002013','-')
            line_list_array = numpy.zeros(len(line_list))
            for i in range(0,len(line_list)):
                line_list_array[i] = float(line_list[i])
            my_mat[index-1,:] = line_list_array[0:2160]
        index += 1
    my_file.close()
    return my_mat

########################################################################################################################


mat = cv2.imread("/Users/liangyiying/Desktop/fx/IMG_6842.jpg")

#mat_array = array(mat)
print(type(mat))
print(shape(mat))
#mat = read_file("/Users/liangyiying/Desktop/fx/IMG_6842.jpg")


        
img = mat[:,:,0].copy()
for i in range(0, 2160):
    for j in range(0, 2160):
        if img[i][j] <= 120:
            img[i][j] = 1
        else:
            img[i][j] = 0
            

plt.imshow(img)
plt.show()
                    
"""                  
img_bian = numpy.zeros((2160, 2160))

img_panduan = numpy.pad(img, constant_values=0, pad_width=1)
for i in range(1, 2161):
    for j in range(1, 2161):
        if img_panduan[i][j] == 255:
            flag = 0
            for ii in range(i - 1, i + 2):
                for jj in range(j - 1, j + 2):
                    if img_panduan[ii][jj] == 0:
                        flag = 1
            if flag == 1:
                img_bian[i - 1][j - 1] = 1
img_bian[0, :] = 0
img_bian[2159, :] = 0
img_bian[:, 0] = 0
img_bian[:, 2159] = 0


img_bian_xi = morphology.skeletonize(img_bian, method="zhang")
"""

img_bian_xi = morphology.skeletonize(img,method="zhang")

img_z = Image.fromarray(img_bian_xi).convert('RGB')
img_z.save("/Users/liangyiying/Desktop/fx.jpg")

        
logN = []
logfR = []
for logR in numpy.arange(0.1, 1.5, 0.2):
    print('************')
    R = (10) ** logR
    N = 0
    for i in range(0, math.ceil(int(2160 / R))):
        for j in range(0, math.ceil(int(2160 / R))):
            box1 = float(i * R)
            box2 = float((i + 1) * R)
            box3 = float(j * R)
            box4 = float((j + 1) * R)
            flag = 0
            for ii in range(int(box1), math.ceil(box2)):
                for jj in range(int(box3), math.ceil(box4)):
                    if img_bian_xi[ii][jj] == 1:
                        flag = 1
            if flag == 1:
                N += 1

    logN.append(math.log(N, 10))
    logfR.append((-1) * math.log(R, 10))

        
shangxian = len(logfR)
xiaxian = 0

XYB = (array(logfR)[xiaxian:shangxian] * array(logN)[xiaxian:shangxian]).sum() / (shangxian - xiaxian)
XBYB = array(logfR)[xiaxian:shangxian].sum() * array(logN)[xiaxian:shangxian].sum() / (
                        shangxian - xiaxian) / (shangxian - xiaxian)
XXB = (array(logfR)[xiaxian:shangxian] * array(logfR)[xiaxian:shangxian]).sum() / (shangxian - xiaxian)
XBXB = array(logfR)[xiaxian:shangxian].sum() * array(logfR)[xiaxian:shangxian].sum() / (
                        shangxian - xiaxian) / (shangxian - xiaxian)
b = (XYB - XBYB) / (XXB - XBXB)
print(b)

      


