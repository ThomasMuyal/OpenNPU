import tkinter as tk
from tkinter import ttk
from tkinter import filedialog as fd
from tkinter.messagebox import showinfo

class Gui:
    def __init__(self, *args, **kwargs):
        self.filename = ""

        return super().__init__(*args, **kwargs)

    def select_file(self):
        filetypes = (
            ('text files', '*.txt'),
            ('All files', '*.*')
        )

        filename = fd.askopenfilename(
            title='Open a file',
            initialdir='/',
            filetypes=filetypes)
        self.filename = filename
        showinfo(
            title='Selected File',
            message=filename
        )
        self.root.destroy()

    def browseFiles(self):
        self.root = tk.Tk()
        self.root.title('OpenNPU')
        self.root.resizable(False, False)
        self.root.geometry('300x150')

        open_button = ttk.Button(
            self.root,
            text='Open a File',
            command=self.select_file
        )
        text0 = ttk.Label(
            self.root, 
            text = '    Welcome to OpenNPU.\n\n     Please select a .tflite file to interpret and \n    generate the custom hardware accelerator'
            )
        text0.pack()
        open_button.pack(expand=True)


        # run the application
        self.root.mainloop()