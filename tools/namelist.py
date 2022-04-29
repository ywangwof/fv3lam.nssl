#!/usr/bin/env python3
## ---------------------------------------------------------------------
##
## This is a python program/module that decode Fortran namelist file
## and do simple processing, write in simple format, compare two
## namelist files, etc.
##
## ---------------------------------------------------------------------
##
## HISTORY:
##
##   Yunheng Wang (05/18/2012)
##   Initial version based on early works for multiple projects.
##
##
########################################################################
##
## Requirements:
##
##   o Python 3.6 or above
##
########################################################################

import filecmp
from itertools import zip_longest
import re, sys
import shutil
from collections.abc import MutableSequence
import tempfile

##%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

class VariableValue(MutableSequence):
    """
    Extend the list built-in for namelist variable values
    This is an internal class and should not be used outside of this module

    Added features are:

      o Comment for this variable
      o type of this variable

    All variable values are converted into a string and wrapped in a list,
    even for value of one element.

    """

    def __init__(self,alist,var_name='',separator=',',comment=None):
        super().__init__()

        if not isinstance(alist,list):
              raise ValueError('Passed in Value "%s" for variable <%s> is not a list.'%(repr(alist),var_name))
        if len(alist) <= 0:
              raise ValueError('Value for variable <%s> cannot be empty "%s".'%(var_name,repr(alist)))

        self._inner_list = alist
        self._sep        = separator         # delimiter between values
        self.varname = var_name
        self.comment = comment
        self.data = self._inner_list
        try:
            self.unpack(self.data)
        except TypeError or ValueError:
            print(f'WARNING: Invalid value for \"{var_name}\": {self.data}',file=sys.stderr)

    def __len__(self):
        return len(self._inner_list)

    def __delitem__(self, index):
        self._inner_list.__delitem__(index)

    def insert(self, index, value):
        self._inner_list.insert(index, value)

    def __setitem__(self, index, value):
        self._inner_list.__setitem__(index, value)

    def __getitem__(self, index):
        return self._inner_list.__getitem__(index)

    def append(self,value):
        self._inner_list.append(value)

    def extend(self,value):
        self._inner_list.extend(value)

    def __repr__(self):
        return repr(self._inner_list)

    def __str__(self):
        if isinstance(self._inner_list[0],list) :
          lstr = ''
          for el in self._inner_list :
            lstr += str(self.unpack(el))+self._sep+' '
          return lstr

        return self._sep.join(self._inner_list)
    #endif

    ####################################################################

    @property
    def value(self) :
      '''
          return unpacked value as python internal data type

          get rid of list symbol for single value
      '''

      if len(self._inner_list) > 1:
          newvalue = []

          for valel in self._inner_list:
             newel = self.unpack(valel)
             newvalue.append(newel)

      else:

          #assert(len(self._inner_list[0])==1)
          valnml = self._inner_list[0]
          #print valnml
          newvalue = self.unpack(valnml)

      return newvalue

    ####################################################################

    @property
    def datatype(self):
        '''
           Detect the value type as:
           int, str, float, bool, arrayofint1d, listint2d, ...
        '''
        outtyp = ''

        dim = 0
        if len(self._inner_list) > 1:
            outtyp = 'arrayof_'
            dim = 1

        valnml = self._inner_list[0]
        #
        # check dimension
        #
        while isinstance(valnml,list):
            dim += 1
            valnml = valnml[0]

        if dim > 0: outtyp += f'{dim}d_'

        assert isinstance(valnml,str)

        if valnml.startswith("'") and valnml.endswith("'"):
          outtyp += 'str'
        elif valnml.startswith('"') and valnml.endswith('"'):
          outtyp += 'str'
        elif self.isbool(valnml):
          outtyp += 'bool'
        elif valnml.isdigit():
          outtyp += 'int'
        elif re.match(r'[\d.+Eeg\-]+',valnml):
          outtyp += 'float'
        else:
          raise TypeError("Invalid namelist variable value <%s>."%valnml)

        return outtyp

    ####################################################################

    def isequal(self,varvalue,strictcmp):
        '''
           compare itself with "varvalue"

           = False  Not equal
           = True   equal
        '''

        lenself = len(self)
        lenin   = len(varvalue)

        if lenself > lenin or lenself < lenin:
            iret = False
        else:
            iret = self.valueCMPList(self.data,varvalue.data,strictcmp)
        return iret

    ##==================================================================
    @classmethod
    def unpack(cls,valnml):
        '''
           unpack namelist value from internal format of this module
           to a Python data type
        '''
        if isinstance(valnml,list):
            newvalue = []
            for valel in valnml:
               newel = cls.unpack(valel)
               newvalue.append(newel)
            return newvalue

        assert isinstance(valnml,str)
        if valnml.startswith("'") and valnml.endswith("'"):
            return valnml.strip("'")

        if valnml.startswith('"') and valnml.endswith('"'):
            return valnml.strip('"')

        if cls.isbool(valnml):
            if valnml.lower() in ('.t.', '.true.'):
                return True
            return False

        if valnml.isdigit():
            return int(valnml)

        if re.match(r'^[+-]?(\d+(\.\d*)?|\.\d+)([eE][+-]?\d+)?$',valnml):
            return float(valnml)

        raise TypeError("Invalid variable value <%s>."%valnml)

    #enddef

    ##==================================================================

    @classmethod
    def pack(cls,valuein) :
        ''' Pack passing in value (one element) for namelist variable to
            internal format for this module.

            Note that it still does not wrap scale value into a list as
            required in "append".
        '''

        if isinstance(valuein,list):
            newvalue = []
            for el in valuein:
                newel = cls.pack(el)
                newvalue.append(newel)
        elif type(valuein) in [int,float] :  ## number should be converted to string
            newvalue =str(valuein)
        elif cls.isastring(valuein) :        ## str should be double wrapped
            newvalue = f"'{valuein}'"
        elif cls.isbool(valuein) :           ## frotran boolean should be wrapped
            newvalue = valuein
        elif valuein is None :
            newvalue = 'None'
        else :
            raise ValueError('''Unsupport namelist variable value "%s" - %s.'''%(valuein,type(valuein)))

        return newvalue
    #enddef

    ##==================================================================

    @classmethod
    def pack2list(cls,valuein) :
        ''' Pack passing in value for namelist variable by wrapping everything
            inside a list.
        '''

        newvalue = []
        if isinstance(valuein,list) :         ## list is kept as a list
            for el in valuein :
               newel = cls.pack(el)
               newvalue.append(newel)

        else:                                 ## otherwise wrap inside a list
            newvalue.append(cls.pack(valuein))

        return newvalue
    #enddef

    ##==================================================================

    @staticmethod
    def isastring(valin) :
      ''' Check whether the passing value is a character string
      '''
      if not isinstance(valin,str) :
        return False

      if VariableValue.isbool(valin):
        return False

      return True

    #enddef

    ##====================================================================

    @staticmethod
    def isbool(valin) :
        ''' Check whether the passing value is a boolean string.
            pass-in value is a string
        '''
        if not isinstance(valin,str) :
          return False

        return valin.lower() in ('.true.','.false.','.t.','.f.')
    #enddef

    ##====================================================================

    @staticmethod
    def isfloat(element: str) -> bool:
        ''' Check whether the passing value is a float number
            pass-in value is a string
        '''
        try:
            float(element)
            return True
        except ValueError:
            return False

    ##====================================================================

    @staticmethod
    def valueCMPList(list1,list2,strictcmp) :
        ''' compare two lists, return True if same otherwise return False '''

        if len(list1) == len(list2) :
            if isinstance(list1[0],list) :      # Value is a list or a list of lists
                strictopts = [strictcmp] *len(list1)
                retl = map(VariableValue.valueCMPList,list1,list2,strictopts)
                if False in retl:
                    ret = False
                else :
                    ret = True
            else :
                for el1,el2 in zip(list1,list2):

                    if strictcmp:
                        ret = (el1 == el2)
                    else:
                        try:
                            val1 = VariableValue.unpack(el1)
                            val2 = VariableValue.unpack(el2)
                            ret = (val1 == val2)
                        except TypeError as atyerror:
                            ret = (el1 == el2)

                    if not ret: break
        else :
            ret = False

        return ret
    #enddef valueCMPList

##%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

class namelistBlock(dict) :
    """
    Extend the dict built-in for namelist handling
    Added features are:

      o Ordered keys
      o Comment for this namelist block
      o Append method, should be used to add new key

    All variable values are converted into a string and wrapped in a list,
    even for value of one element.

    Uses key as attribute. Note that it is assumed that keys are all Fortran
    variable name and it will not conflict with the namespace of builtin
    dict method attributes

    There are two sets of references:
        1. dict notation gets and sets "VariableValue" instance,
           which has attributes: value, data, datatype, comment, varname etc.
        2. (preferred) attr notation gets and sets Python/Fortran internal data type
           (int, float, str, list)

    String representation:
        1. str()  To get Fortran namelist file output (readable)
        2. repr() To get internal representation, for debugging etc.
    """

    def __init__(self,name='',separator='=',comment=None) :
      dict.__init__(self)
      self._order   = []
      self._name    = name
      self._sep     = separator
      self._comment = comment
 #  enddef

    ####################################################################

    def keys(self) :
      return self._order
    #enddef

    ######################################################################

    def getComment(self,key=None) :
      if not key :
        return self._comment

      return self[key].comment
    #enddef

    ######################################################################

    def append(self,key,value,valsep,comment=None) :
        '''
            "value" must be a list, all elements in the list must be string
            string value is extra wrapped within ' and '

            It only append values to existing key or create new (key, value) pair.
            To replace value of existing key, use either
               o the dict notation, self[key] = value,
                 value must be already wrapped as mentioned above
               o the attribute notation, self.key = value
                 value will be in normal Fortran format.

        '''
        multidim = False   ## maximum to process 2 dimensions
        indx1 = 0
        #print 'Adding key :',key
        #                        1            2       3 4
        regroups = re.match(r'([\w_ ]+)\(([\d:]{1,2})(,(\d{1,2})){0,2}\)',key)
        if  regroups:
            key = (regroups.group(1)).strip()
            if regroups.group(2) == ':': indx1 = 0
            else:                        indx1 = int(regroups.group(2))
            if regroups.group(3) :
                multidim = True
                indx2 = int(regroups.group(4))

        if key in self:
            if multidim :
                if indx2 > len(self[key]):
                  self[key].append(value)
                else :
                  self[key][indx2-1].extend(value)
            else :
                if indx1 > 1: assert indx1-1 == len(self[key])
                self[key].extend(value)
        else :
            if multidim:
                valuelist = [value]
            else :
                if indx1 > 1: key = '%s(%d)' % (key, indx1)
                valuelist = value

            varvalue = VariableValue(valuelist,key,valsep,comment)

            self.__setitem__(key,varvalue)
            self._order.append(key)
    #enddef

    ####################################################################

    def __dir__(self):
          return self.keys()

    ####################################################################

    def __getattr__(self, key):
      try:
          return self[key].value
      except KeyError as key_error:
          print ('''Variable "%s" is not a member of this namelist block: <%s>.''' % (key,self._name))
          raise AttributeError(key) from key_error

    ####################################################################

    def __setattr__(self, key, value):
      if key in ['_comment', '_order', '_sep', '_keycomments', '_name']:
          super().__setattr__(key,value)
      else:
          valnml = VariableValue.pack2list(value)

          if key in self.keys():
              self[key] = VariableValue(valnml,key)
          else:
              self.append(key,valnml,'new variable')

    ####################################################################

    def __setitem__(self, key, value):

        if isinstance(value,VariableValue):
            super().__setitem__(key, value)
        else:
            raise ValueError('''Value "%s" is not an instance of class VariableValue.'''%value)

    ####################################################################

    def item (self, key):
        ''' return one (key,value) pair as a string'''

        value_list = self[key]
        # value_list is an instance of VariableValue
        # but it can be used as a list

        outstr = ''
        if isinstance(value_list[0],list) :
            indx2 = 0
            for value in value_list :
                indx2 += 1
                outstr += f"{key}(:,{indx2}) {self._sep} {value_list._sep.join(value)}{value_list._sep}\n"
        else :
                outstr += f"{key} {self._sep} {value_list._sep.join(value_list)}{value_list._sep}" #{value_list.comment}"

        return outstr

    ######################################################################

    def __repr__(self):
      ''' repr() for debugging'''

      outstr = f'&{self._name}\n'
      for var_name in self.keys() :
          outstr += f"  {var_name} {self._sep} {repr(self[var_name])}\n"

      outstr += '/\n\n'

      return outstr

    ######################################################################

    def __str__(self):
      ''' print or str()'''

      if self._sep == '=':
          outstr = '&%s\n'%self._name
      else:
          outstr = ''

      for var_name in self.keys() :
          outstr += f"  {self.item(var_name)}\n"

      if self._sep == '=': outstr += '/\n\n'

      return outstr

    ##==================================================================

    @classmethod
    def clone_from_dict(cls,dictin):
      '''
         Create a namelistBlock from "dict"
      '''

      nmlblk = cls('indict','Namelist block from python dictionary')

      for key,value in dictin.items():
          #nmlblk.__setattr__(key, value)
          nmlval = VariableValue.pack2list(value)
          nmlblk.append(key,nmlval)

      return nmlblk

#endclass

##%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

class namelistGroup(dict) :
    '''
    Contain all namelist blocks in one file

    Added features:
      _order : list to return ordered keys, i.e. namelist block names,
      value  : is the namelist block corresponding to this name.
    '''

    def __init__(self,filename=None) :
      dict.__init__(self)
      self._order   = []
      self._srcfile = filename
      self.merge    = self.merge1dict    # to keep backward compatible
      self.outblocks = None
    #enddef

    ######################################################################

    def keys(self) :
        return self._order
    #enddef

    ######################################################################

    def __setitem__(self,key,value) :
        dict.__setitem__(self,key,value)
        self._order.append(key)
    #enddef

    ######################################################################

    def __repr__(self):
        '''repr() for debugging, formally representation of the object'''

        if self.outblocks is None:
            self.outblocks = self.keys()

        outstr = ''
        for _nml_name in self.outblocks :
            outstr += repr(self[_nml_name])

        return outstr

    ######################################################################

    def __str__(self):
        ''' print or str(), for readable output'''

        if self.outblocks is None:
            self.outblocks = self.keys()

        outstr = ''
        for _nml_bname in self.outblocks:
            outstr += str(self[_nml_bname])

        return outstr

    ######################################################################

    def merge1dict(self,indict,nblkname=None,forceadd=False):
        '''
        Merge 1-level dictionary to this file.

        Merge the give varaibles in a dict (indict) into this namelsit group.
        all keys in indict must exists in the namelist variables, otherwise
        a warning is issued.
        '''

        if isinstance(indict,namelistBlock):
          inblk = indict
        else:
          inblk = namelistBlock.clone_from_dict(indict)
          #print inblk

        set1 = set(inblk.keys())

        if nblkname is None:
            nmlblocks = self.keys()
        else:
            nmlblocks = nblkname

        for _nml_name in nmlblocks :       ## loop over all namelist blocks
            _nml_block = self[_nml_name]
            set0 = set(_nml_block.keys())      ## variable set of this namelist block
            setc = set0.intersection(set1)     ## Keys to be updated
            if len(setc) > 0 :                 ## this block contains variable to be merged
                for var in setc :
                    _nml_block[var] = inblk[var]
                    #print "%s -> <%s>" % (var, _nml_block[var])

            set1 = set1.difference(setc)      ## Keys left to be merged with other namelis block
            if len(set1) <= 0 : break

        #
        # extra variables from input dict
        #
        if len(set1) > 0 :
            if forceadd:
                for nmlname in nblkname:
                    if nmlname in self.keys():
                        sys.stderr.write('WARNING: Unknown variables \"%s\" while merging namelist <%s>. Adding...\n'%(','.join(set1),inblk._name))
                        for var in set1:
                            newvalue = inblk[var]
                            self[nmlname].append(var,newvalue,'New from %s'%inblk._name)

                            #print >> sys.stderr, self[nmlname].getComment(var)
            else:
                sys.stderr.write('WARNING: Unknown variables \"%s\" while merging namelist <%s>. Ignored.\n'%(','.join(set1),inblk._name))
                #sys.stderr.write('WARNING: Unknown variables \"%s\" while merging namelist. Ignored.\n'%(','.join(set1)))
    #enddef

    ######################################################################

    def merge2dict(self,indict,blknames=None,forceadd=False):
        '''
        Merge 2-level dictionary to this file.

        Merge the given dictionary (indict) into this namelsit group.
        all keys in "indict" must be a name of namelistBlock in this namelistGroup
        otherwise warning will be issued.
        '''

        if isinstance(indict,namelistGroup):
            ingrp = indict
        else:
            ingrp = namelistGroup.fromDict(indict)

        if blknames is None:
            mergenml = ingrp.keys()
        else:
            mergenml = blknames

        for _nml_name in mergenml:             ## loop over all namelist blocks, it is a "dict" again
            if _nml_name in self.keys():         ## make sure indict key is valid
                _nml_block = self[_nml_name]
                for key,value in ingrp[_nml_name].items():

                    if key in _nml_block.keys():         # make sure variable is valid
                        _nml_block[key] = value
                    elif forceadd:
                        _nml_block.append(key,value.data)
                        sys.stderr.write('WARNING: Variables \"%s\" in namelist <%s> is not in the namelist file <%s>. Adding...\n'%(
                                          key, _nml_name,self._srcfile))
                    else:
                        sys.stderr.write('WARNING: Variables \"%s\" in namelist <%s> is not in the namelist file <%s>. Ignored.\n'%(
                                          key, _nml_name,self._srcfile))

            else:
                sys.stderr.write('WARNING: name \"%s\" from passed in dict is not in the namelist file <%s>. Ignored.\n'%(_nml_name,self._srcfile))

    #enddef

    ######################################################################

    def writeToFile(self,filein, blks=None):
        '''Write a run-time namelist file.'''

        if blks is not None:
            self.outblocks = blks

        if isinstance(filein, str):
            with open(filein,'w') as nml_file:
                nml_file.write(str(self))
        else :
            filein.write(str(self))

    #enddef writeToFile

    ##
    ########################################################################
    ##
    ## Merge a namelistGroup to a namelist file
    ##
    ########################################################################
    ##
    def writeToFileWithComments(self, outfhdl, blks=None, debug=False, forceadd=False) :
        '''Write variable values in this namelistGroup object to a new file
           by keeping the comments and format in the original namelist file.

           The purpose of this method is to keep the comments and format in
           the original file, but replace variable values with those in
           this namelist Group.
        '''

        if blks is not None:
            self.outblocks = blks
        else:
            self.outblocks = self.keys()

        inmlblock = False
        var_names = []                   # var processed so far, to avoid duplication
        var_pend = False                 # var pending for output
        var_found= None

        # Inner function to process one text line
        def find_var_one_line():

            nonlocal line

            value    = ''
            if debug : print(f'\n--- {line}')

            linelist = line.split(',')      ## variable line
            str_con  = False

            for i,element in enumerate(linelist) :

                if element == ''           : continue     ## skip empty element
                if element.startswith('!') : break        ## ignore all following elements

                if debug: print(f'\n= {i}: {element}', end='')

                if str_con :                       ## value is still not complete
                    value += ",%s" % element
                    if value.endswith("'") :
                        str_con = False
                    continue

                element = element.strip()

                if element.find('=') > 0:       ## find a variable

                    [var_new,value] = element.split('=',1)
                    var_new = var_new.strip()

                    regroups1 = re.match(r'([\w_]+)\s*\([:\d]+\)',var_new)
                    regroups2 = re.match(r'[:\d]+\)',var_new)
                    if regroups1 :
                        var_found = regroups1.group(1).lower()
                        if var_found not in self[nml_name].keys():
                            var_found = var_new.lower()
                    elif regroups2:
                        pass
                        # use var_found with last element
                    else :
                        var_found = var_new.lower()

                    var_pend = True
                    if debug : print (f'\n    Found variable "{var_found}"')

                    value = value.strip()
                    if value.startswith("'") and not value.endswith("'") :  ## string value to be continued
                        str_con = True
                else :
                    regroups = re.match(r'([\w_]+)\s*\([:\d]+',element)
                    if regroups :       ## handle 2D variable, var(1,
                        var_found = regroups.group(1).lower()
                        var_pend = True   ## 2. Found new variable
                        continue

                    if element.startswith("'") and not element.endswith("'") :
                        str_con = True

                if var_pend and var_found not in var_names :
                                                 ## 1. WRITE previous variable found
                    if debug : print(f'    Writing variable "{var_found} = {self[nml_name][var_found]}" ...')
                    #self.writevar(outfhdl,nml_name,var_found)
                    outfhdl.write(f'  {self[nml_name].item(var_found)}\n')
                    var_names.append(var_found)
                    var_pend = False
            return
        # end of inner function

        # go throught the namelist file line by line to find variables
        with open(self._srcfile) as fp:
            for txtline in fp:
                line = txtline.strip()
                if line.startswith('!')  :      ## comment ignore
                    outfhdl.write(f'{line}\n')   ## just print
                elif line.startswith('&') and line[1:4] != 'end' :    ## start a namelist block
                    nml_name = line[1:]
                    inmlblock = True if nml_name in self.outblocks else False
                    var_names = []
                    var_found = None
                    outfhdl.write(f'{line}\n')        ## print namelist block name
                elif line.startswith('/') or line[:4] == '&end' :    ## close a namelist block
                    if var_pend and var_found not in var_names :   ## 2. WRITE at last within namelist block
                        outfhdl.write(f'  {self[nml_name].item(var_found)}\n')
                        var_pend = False

                    if forceadd:
                        set1 = set(self[nml_name].keys())
                        set1 = set1.difference(set(var_names))
                        for var_name_in in set1:
                            outfhdl.write(f'  {self[nml_name].item(var_name_in)}\n')

                    inmlblock = False
                    outfhdl.write('/\n')
                else :
                    if not inmlblock :            ## everything outside a namelist block
                        outfhdl.write(f'{txtline}')
                        continue

                    if not line : continue        ## ignore blank lines

                    find_var_one_line()

    #enddef writeToFileWithComments

    ######################################################################

    @classmethod
    def fromDict(cls,indict):
        '''
           Create a namelistGroup from double level dictionary

        '''

        _nmlgrp = cls('dict')

        for _nml_name in indict.keys() :       ## loop over all namelist blocks, it is a "dict" again
            _nmlgrp[_nml_name] = namelistBlock.clone_from_dict(indict[_nml_name])

        return _nmlgrp


    ##
    ########################################################################
    ##
    ## Process namelist file
    ##
    ########################################################################
    ##
    @classmethod
    def fromFile(cls,file_name,varsep,debug=False,dictionary=False) :
        '''read and parse a namelist file

           note that each variable is a string
           value is also string, but enclosed within a list
           string wrapped within ' and '.

           return a namelistGroup object
        '''
        nml_grp = cls(file_name)  ## Contain the whole namelist file

        #debug = False
        if dictionary:
            nml_name = 'global'
            nml_block = namelistBlock(name=file_name, separator = varsep)
            inmlblock = True
        else :
            inmlblock = False

        if varsep == ':':         # variable and value(s) delimiter
            valsep = ' '          # values delimiter
        else:
            valsep = ','

        var_name   = ''          # working array
        value_list = None        # we are sure one variable is completed only when
        var_next   = False       # Found next variable name, so current variable is ready to be added
        var_comment = ''

        variables    = {}          # Collect all variables and values for output
        varcomments  = {}

        blkcomments = []

        # Inner function  add_one_variable
        def add_one_variable():
            '''Added variable/value to the variables dict for current namelist block'''

            nonlocal var_name, value_list
            nonlocal variables

            if var_name in variables.keys():
                print(f"WARNING: duplicated variable \"{var_name}\" found, use the last value {value_list}.",file=sys.stderr)

            variables[var_name.lower()]   = value_list
            varcomments[var_name.lower()] = var_comment
            if debug : print(f'\n    adding "{var_name} = {value_list}" to namelist block <{nml_name}>', end='')

            # get ready for next variable
            value_list  = None
        # end of inner function add_one_variables

        # Inner function decode_one_line
        def decode_one_line():
            '''
               Decode one source line, this line can be
                  o. var = value,
                  o. var(1,2) = value,
                  o. var1 = value1, var2 = value2, .....
                  o. var = 'string, value',    # "," within string
                  o. value1, value2, ...       # to complete earlier line

                Variable inherited from the caller and may be update in this method:
                    var_name,value_list,var_next     # current variable and status
            '''

            nonlocal line
            nonlocal var_next, var_name, value_list, var_comment

            var_no   = 0                    ## how many variables contained in one line?
            var_pre  = ''                   ## prefix for unfinished variable name
            str_con  = False                ## in case , is within a string
            multidim = False

            #debug = (nml_name == 'jobname')
            if debug : print(f'\n\n--- {line}', end='')

            linelist = line.split(valsep)      ## variable line

            # filter out empty elements and comments
            valid_list = []
            for i,element in enumerate(linelist):
                newele = element.strip()
                if newele == '' or newele == ' ':
                    continue
                elif newele.startswith('#') or newele.startswith('!'):
                    var_comment = valsep.join(linelist[i:])
                    break
                else:
                    valid_list.append(newele)

            # go through each element in this line
            for i,element in enumerate(valid_list):

                if debug: print(f'\n= {i}: {element}', end='')

                if str_con :                           ## value is still not complete
                    value += f",{element}"
                    if value.endswith("'") :
                        if value_list is None :
                          value_list = [value]         ## initialize the variable value list
                        else :
                          value_list.append(value)

                        str_con = False
                    if debug: print(f'Appened to value string as: {value}', end='')
                    continue

                element = element.strip()
                #if element == '' or element == ' ':  continue           ## skip empty element
                #if element.startswith('!') or element.startswith('#'):
                #    var_comment = element
                #    continue                                            ## skip all following elements

                if element.find(varsep) > 0:         ## find a variable
                    if var_no > 0 or var_next:       ## Already find a variable before, so save it to "nmlblock"
                        add_one_variable()
                        var_next    = False

                    [var_name,value] = element.split(varsep,1)
                    var_name = var_name.strip()
                    var_no += 1
                    var_next = True

                    if var_pre :                    ## prepend "var(1," (decoded early) to "1)" (current)
                        var_name = var_pre + ',' + var_name
                        var_pre = ''
                        multidim = False
                    if debug: print(f'\n    Found new variable name: {var_name}', end='')

                    value = value.strip()
                    if element.startswith("'") and not element.endswith("'") :  ## string value to be continued
                        str_con = True
                    else:
                        if value == '':
                            value_list = []
                        else:
                            value_list = [value]      ## initialize the variable value list
                    if debug: print(f' and value: {value} -> {value_list}')
                else :                             ## pure value part, or multiple dimension variable names
                    regroups = re.match(r'[\w_]+\([:\d]+',element)
                    if regroups :
                        multidim = True
                        var_pre  = element            ## handle 2D variable, var(1,
                        continue

                    regroups = re.match(r'\d+',element)
                    if regroups and multidim :
                        var_pre += ','+element
                    else :
                        if element.startswith("'") and not element.endswith("'") :
                            ## string value to be continued
                            str_con = True
                            value = element
                        elif element.startswith('!') or element.startswith('#'):
                            var_comment += element
                        else:
                            value_list.append(element)     ## append variable values

            return
        # end of inner function decode_one_line


        # Go through the namelist file line by line
        with open(file_name) as fp:
            for txtline in fp:
                line = txtline.strip()
                if line.startswith('!')  :      ## comment ignore
                    #pass  ## do nothing at present
                    blkcomments.append(line)
                elif line.startswith('&') and line[1:4] != 'end' :    ## start a namelist block
                    nml_name = line[1:]
                    blkcommentstr = '\n'.join(blkcomments)
                    nml_block = namelistBlock(name=nml_name, separator = varsep, comment=blkcommentstr )
                    inmlblock = True
                    blkcomments = []
                elif line.startswith('/') or line[:4] == '&end' :    ## close a namelist block
                    if var_next:                                     ## process the last variable before close this namelist block
                        add_one_variable()
                        var_next = False

                    for varname,varval in variables.items():
                        nml_block.append(varname, varval,valsep, varcomments[varname])

                    nml_grp[nml_name] = nml_block
                    if debug : print(f'\n+++ adding namelist block <{nml_name}>')
                    inmlblock = False

                    variables = {}         # Clear current namelist block for new one

                else :
                    if not inmlblock or not line: continue
                                                    ## ignore everything outside a namelist block
                                                    ## and blank line inside a namelist block
                    decode_one_line()

        if dictionary :    ## contain only var = value pairs
            if var_next:
                add_one_variable()
                var_next    = False

            for varname,varval in variables.items():
                nml_block.append(varname, varval, valsep, varcomments[varname])
                if debug : print(f'\n+++ adding "{varname} = {varval}" from a dictionay.',end='')

            nml_grp[nml_name] = nml_block

        return nml_grp
    #enddef

#endclass

##%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

class namelistCMPGroup(dict) :

    def __init__(self,nmlgrpL,nmlgrpR,strict=False) :
      dict.__init__(self)
      self.__setitem__('namelistL',[])
      self.__setitem__('namelistR',[])
      self.__setitem__('namelistC',{})

      setL = set(nmlgrpL.keys())
      setR = set(nmlgrpR.keys())

      set0 = setL-setR
      set1 = setR-setL
      setC = setL & setR

      if len(set0) > 0 :
        self['namelistL'].extend(set0)

      if len(set1) > 0:
        self['namelistR'].extend(set1)

      for nml_name in setC :  ## loop over all common namelist blocks

        nmlC = { 'varL': [],
                 'varR': [],
                 'varC': [],
                 'varS': []
                }

        nmlL = nmlgrpL[nml_name]
        nmlR = nmlgrpR[nml_name]

        varL = set(nmlL.keys())
        varR = set(nmlR.keys())

        var0 = varL-varR
        var1 = varR-varL
        varC = varL & varR

        if len(var0) > 0 :
          nmlC['varL'].extend(var0)

        if len(var1) > 0:
          nmlC['varR'].extend(var1)

        if len(varC) > 0 :         ## this block contains common variables
          for var in varC :
            valueL = nmlL[var]
            valueR = nmlR[var]
            if valueL.isequal(valueR,strict):
                nmlC['varS'].append(var)
            else :
                nmlC['varC'].append(var)

        self['namelistC'][nml_name] = nmlC
    #enddef

    ######################################################################

    def output(self,ofile,grp1,grp2,nmlblknames=None,color=True) :
        ''' Print the comparison results '''

        if color :
            cprint = self.colorprint
        else :
            cprint = self.nprint

        left  = cprint("left ",'magenta')
        right = cprint("right",'cyan')

        print(' ')
        print('='*100, file = ofile)
        leftstr  = f"{left} : {grp1._srcfile}"
        rightstr = f"{right} : {grp2._srcfile}"
        print(f"{' ':6} {leftstr:<60} {rightstr:<60}", file = ofile)

        nmllftH = ''
        nmllftN = ''
        if len(self['namelistL']) > 0 :
            nmllftH = '++++ namelist only in %s +++++' % left
            nmllftN = cprint(self['namelistL'],'red')

        nmlrgtH = ''
        nmlrgtN = ''
        if len(self['namelistR']) > 0 :
            nmlrgtH = '++++ namelist only in %s ++++' % right
            nmlrgtN = cprint(self['namelistR'],'blue')

        if len(self['namelistL']) > 0  or len(self['namelistR']) > 0 :
            print(f"{' ':<6} {'-'*40}        {'-'*40}", file = ofile)
            print(f"{' ':<6} {nmllftH:<60} {nmlrgtH:<60}", file = ofile)
            print(f"{' ':<6} {nmllftN:<60} {nmlrgtN:<60}", file = ofile)

        print(  '#'*100, file = ofile)

        if nmlblknames is None:
            outnmlblks = grp1.keys()
        else:
            outnmlblks = nmlblknames

        #for nml in self['namelistC'].keys() :  # to keep namelist block order in the base file
        for nml in outnmlblks:
            if nml in self['namelistC'].keys():

                nmlC = self['namelistC'][nml]

                prnthead = False
                headnml  = '&%s' % cprint(nml,'yellow')
                if (len(nmlC['varL']) > 0  or len(nmlC['varR']) > 0 or len(nmlC['varC']) > 0) and grp1[nml]._sep != ':':
                    prnthead = True

                if prnthead: print('\n%s' % headnml, file = ofile)

                varlefH = ''
                if len(nmlC['varL']) > 0 :
                    varlefH = '<<<< left-only variable(s) >>>>'

                varrgtH = ''
                if len(nmlC['varR']) > 0 :
                    varrgtH = '>>>> right-only variable(s) <<<<'

                if len(nmlC['varL']) > 0 or len(nmlC['varR']) > 0:
                    print(f"{' ':<13} {varlefH:<40} {varrgtH:<50}", file = ofile)

                    for varl,varr in zip_longest(nmlC['varL'],nmlC['varR'],fillvalue=' '):
                        rightc = ' ' if varr == ' ' else f"{cprint(varr,'cyan').ljust(14)} {grp2[nml]._sep} {grp2[nml][varr]}"
                        if varl == ' ':
                            print(f"{' ':<57}  {rightc:<40}", file = ofile)
                        else:
                            leftc = f"{cprint(varl,'magenta').ljust(14)} {grp1[nml]._sep} {grp1[nml][varl]}"
                            print(f"{' ':<17} {leftc:<53} {rightc:<40}", file = ofile)

                    print(' ','-'*54,' ','-'*40, file = ofile)

                if len(nmlC['varC']) > 0:              ## these are the command variables that have difference
                    #for var in nmlC['varC']:    # to keep variable order in the base file
                    for var in grp1[nml].keys():
                        if var in nmlC['varC']:
                            valleft  = str(grp1[nml][var])
                            valright = str(grp2[nml][var])
                            if len(valleft) < 40 and len(valright) < 40:
                                ioffset = len(var)-14 if len(var)>14 else 0
                                strleft  = cprint(valleft,'magenta',38-ioffset)
                                strright = cprint(valright,'cyan',38)
                                print(f'  {str(var).ljust(14)} {grp1[nml]._sep} {strleft} ; {strright}', file = ofile)
                            else:
                                strleft  = cprint(valleft,'magenta')
                                strright = cprint(valright,'cyan',)
                                print(f"  {str(var).ljust(14)} {grp1[nml]._sep} {strleft} ;", file = ofile)
                                print(f"  {' ':<14}  {strright}", file = ofile)
                    #print(' ', file = ofile)

                if prnthead: print(cprint('/','yellow'), file = ofile)
    #enddef

    ##====================================================================

    @staticmethod
    def colorprint(field, color = 'white',length=None, ):
      """Return the 'field' in collored terminal form"""

      Term_colors = {
        'black':30,
        'red':31,
        'green':32,
        'yellow':33,
        'blue':34,
        'magenta':35,
        'cyan':36,
        'white':37,
      }
      #field = ('{:%s%ds}'%(align,length)).format(field)
      outfield = field
      if length :
        if len(field) > length :
            outfield = field[:length-4]+' ...'
        else:
            outfield = field.ljust(length)

      outfield = '\x1B[01;%dm%s\x1B[00m' % ( Term_colors[color], outfield )
      ##field = '{:20s}'.format(field)
      return outfield
    #enddef colorprint

    ##====================================================================

    @staticmethod
    def nprint(field, color = 'white', length=None,):
      """Return the 'field' in collored terminal form"""

      outfield = str(field)
      if length :
        if len(field) > length :
            outfield = field[:length-4]+' ...'
        else:
            outfield = field.ljust(length)

      return outfield
    #enddef nprint

#endclass

##======================================================================
## Create a backup file
##======================================================================
def create_a_backup_file(filename):
    '''Create a backup file and backup the file passed in
       Return the backup file name
    '''

    bakfile = f"{filename}.bak"
    if os.path.lexists(bakfile):                      # find a valid backup file name
        bakfile_base = bakfile
        bakfile1     = bakfile
        bi = 1
        bakfile = f"{bakfile_base}{bi:02d}"
        while os.path.lexists(bakfile):
            bi += 1
            bakfile1 = bakfile
            bakfile = f"{bakfile_base}{bi:02d}"

        if not filecmp.cmp(filename, bakfile1):        # do not backup duplicate contents
            shutil.copy(filename,bakfile)
        else:
            bakfile = bakfile1
    else:
        shutil.copy(filename,bakfile)

    return bakfile
#enddef create_a_backup_file

##======================================================================
## Parse command line arguments
##======================================================================

def parseArgv() :
    '''-------------------------------------------------------------------
    Parse command line arguments
    -------------------------------------------------------------------'''

    version  = '6.0'
    lastdate = '2022.04.22'

    parser = argparse.ArgumentParser(description="Fortran Namelist handler",
                    epilog=f"For questions or problems, please contact yunheng@ou.edu (v{version}, {lastdate})")

    parser.add_argument("-v", "--debug", action="store_true", help="More messages while running")
    parser.add_argument("-k", "--keep1", action="store_true", help="Keep FILE1 comments and other namelist blocks (if --name option is given) intact.")
    parser.add_argument("-f", "--force", action="store_true", help="Add new variables from FILE2 if not exist in FILE1")
    parser.add_argument("-d", "--separator",default='=',      help="Variable separator, default: '=' for namelist, ':' for ESMF configuration")
    parser.add_argument("-r", "--strict",action="store_true", help="Strict comparison, two values (float, int, boolean, etc) are different even they have the same value but may be in different formats")
    parser.add_argument("-o", "--output",default=None,        help="Ouput file name")
    parser.add_argument("-i", "--inline",action="store_true", help="Write output inline to the original file, FILE1 (if --output is not given). It implicitly turns on -keep1")
    parser.add_argument("-n", "--name",  default=None,nargs='+',help="Namelist block name(s), Operate with these namelist block(s) only")

    parser.add_argument("-p", "--print", action="store_true", help="Print namelist file, default for 1 file")
    parser.add_argument("-c", "--diff",  action="store_true", help="Compare two namelist files, FILE1 is the base, default for 2 files")
    parser.add_argument("-m", "--merge", action="store_true", help="Merge FILE2 to FILE1, FILE2 is a namelist file")
    parser.add_argument("-s", "--set",   action="store_true", help="Set FILE1 with values from FILE2. FILE2 contains variable \nand value pairs only, but not embeded within namelist blocks")

    parser.add_argument("file1", nargs=1,   help="A Fortran namelist file")
    parser.add_argument("file2", nargs='?', help="Another namelist file or var-value flat file for comparison or merging" )

    args = parser.parse_args()

    options = {'debug': args.debug, 'output' : args.output,  'keep1' : args.keep1,
               'force': args.force, 'inline' : args.inline,  'strict': args.strict,
               'blkname': args.name, 'action' : None, 'varsep': args.separator}

    argfiles = args.file1
    if args.file2 is not None:
        argfiles.append(args.file2)

    if len(argfiles) == 1:
        options['action'] = 'print'
    elif len(argfiles) == 2:
        options['action'] = 'diff'

    if args.print:
        options['action'] = 'print'
    elif args.diff:
        options['action'] = 'diff'
    elif args.merge:
        options['action'] = 'merge'
    elif args.set:
        options['action'] = 'set'

    if options['action'] in ['diff', 'set', 'merge']:
        if len(argfiles) == 2:
            if os.path.isdir(argfiles[1]):
                filename = os.path.basename(argfiles[0])
                argfiles[1] = os.path.join(argfiles[1],filename)
        else:
            print(f"\n  ERROR: 2 files are require to do \"{options['action']}\".", file=sys.stderr)
            sys.exit(0)

    for afile in argfiles:
        if not os.path.lexists(afile):
            print(f"ERROR: file not found - {afile}", file=sys.stderr)
            sys.exit(0)

    if options['inline']: options['keep1'] = True

    return (options, argfiles)
#enddef parseArgv

##@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
##
## Entance Point
##
##@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

if __name__ == '__main__':

  import os, argparse

  (opts,args) = parseArgv()

  dictfmt = False
  if opts['varsep'] == ':': dictfmt = True

  ## Decode a nameliss file to get the base namelist group
  nmlfile = args[0]
  nmlgrp = namelistGroup.fromFile(nmlfile,opts['varsep'],opts['debug'],dictfmt)

  output = True

  if opts['action'] == 'diff' :

    nmlgrp2 = namelistGroup.fromFile(args[1],opts['varsep'],opts['debug'],dictfmt)
    ## compare two namelist groups
    nmlcmp = namelistCMPGroup(nmlgrp,nmlgrp2,opts['strict'])

    if opts['output'] is None :
        nmlcmp.output(sys.stdout,nmlgrp,nmlgrp2,opts['blkname'],True)
    else :
        with open(opts['output'],'w') as outhdl:
            nmlcmp.output(outhdl,nmlgrp,nmlgrp2,opts['blkname'],False)

    output = False        ## done

  elif opts['action']  == 'merge':

    nmlgrp2 = namelistGroup.fromFile(args[1],opts['varsep'],opts['debug'],dictfmt)
    nmlgrp.merge2dict(nmlgrp2,opts['blkname'],opts['force'])

  elif opts['action'] == 'set':

    nmlgrp2 = namelistGroup.fromFile(args[1],opts['varsep'],opts['debug'],True)
    for nmlname,nmlblock in nmlgrp2.items():
        nmlgrp.merge1dict(nmlblock,opts['blkname'])

  ##
  ## Output the namelist file
  ##

  if output :

    if opts['output'] is not None:
        outhdl = open(opts['output'],'w')
    elif opts['inline']:
        bakfile = create_a_backup_file(args[0])
        outhdl  = tempfile.NamedTemporaryFile(mode='w+',delete=False)
    else:
        outhdl = sys.stdout

    if opts['keep1'] :
        nmlgrp.writeToFileWithComments(outhdl,opts['blkname'],opts['debug'],opts['force'])
    else :    ## Output the base namelist
        nmlgrp.writeToFile(outhdl,opts['blkname'])

    outhdl.close()
    if opts['inline']:
        shutil.copy(outhdl.name,args[0])
        print(f"INFO: The original file is backuped in file: {bakfile}",file=sys.stderr)
        os.unlink(outhdl.name)
