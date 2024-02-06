using DocuSign.eSign.Model;
using System.IO;
using System.Windows;
using System.Windows.Forms;
using Timer = System.Timers.Timer;

namespace ExportAllQuery
{
    /// <summary>
    /// Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window
    {
        private Timer timer;
        public MainWindow()
        {
            InitializeComponent();
            //timer = new Timer(1000);
            //timer.Elapsed += new ElapsedEventHandler(timer_Elapsed);
            //timer.Start();
        }
        //void timer_Elapsed(object sender, ElapsedEventArgs e)
        //{
        //    this.Dispatcher.Invoke(System.Windows.Threading.DispatcherPriority.Normal, (Action)(() => {
        //        if (ProgressBarLoading.Value < 100)
        //        {
        //            ProgressBarLoading.Value += 10;
        //        }
        //        else
        //        {
        //            timer.Stop();
        //        }
        //    }));
        //}
        private void folderBrowserDialog1_HelpRequest(object sender, EventArgs e)
        {

        }

        private async void Browse_Click(object sender, RoutedEventArgs e)
        {
            // this is based on https://www.antoniovalentini.com/how-to-handle-file-and- folder-dialog-windows-in-a-wpf-application/

            var ookiiDialog = new Ookii.Dialogs.Wpf.VistaFolderBrowserDialog();
            if (ookiiDialog.ShowDialog() == true)
            {

                //ProgressBarLoading.Value = 10;

                var progress = new Progress<int>(x => ProgressBarLoading.Value = x);

                string filePath = ookiiDialog.SelectedPath;
                PathTextBox.Text = ookiiDialog.SelectedPath;
                WorkerClass worker = new WorkerClass();
              var Result=await Task.Run(() => worker.doSomething(filePath, progress));
                ExportResult.Text = Result;
                if (string.IsNullOrEmpty(Result))
                    ProgressBarLoading.Value = 0;
                else
                ProgressBarLoading.Value = 100;


                string path = ookiiDialog.SelectedPath;

            }

        }
        public class WorkerClass
        {
            public string doSomething(string filePath, IProgress<int> progress)
            {
                DirectoryInfo di = new DirectoryInfo(filePath);
                FileInfo[] fileInfos = di.GetFiles("*.sql", SearchOption.AllDirectories);
                if(fileInfos==null || fileInfos.Length == 0)
                {
                    System.Windows.Forms.MessageBox.Show("فایلی با پسوند .sql  برای پردازش یافت نشد.");
                    return string.Empty;
                }
                else
                {
                    string script = "";
                    bool First = true;
                    var per = fileInfos.Length / 9;
                    progress.Report(5);
                    int Counter = 0;
                    foreach (var fileInfo in fileInfos)
                    {

                        if (Counter == per)
                            progress.Report(15);
                        if (Counter == (per * 2))
                            progress.Report(25);
                        if (Counter == (per * 3))
                            progress.Report(35);
                        if (Counter == (per * 4))
                            progress.Report(45);
                        if (Counter == (per * 5))
                            progress.Report(55);
                        if (Counter == (per * 6))
                            progress.Report(65);
                        if (Counter == (per * 7))
                            progress.Report(75);
                        if (Counter == (per * 8))
                            progress.Report(85);
                        if (Counter == (per * 9))
                            progress.Report(95);
                        // ProgressBarLoading.Value += ProgressBarValue;
                        if (First)
                            script += fileInfo.OpenText().ReadToEnd();
                        else
                            script += "\n" + "GO" + "\n" + fileInfo.OpenText().ReadToEnd();
                        First = false;
                        Counter++;
                    }

                    return script;
                }
                
                //using (var package = new Package(filePath))
                //{
                //    foreach (var item in package)
                //    {
                //        updateMethod(item); //once this method call is complete I want the ProgressBar to update its Value
                //        progress.Report(...);
                //    }
                //}
            }
        }
       
        private void ExportResult_Scroll(object sender, System.Windows.Controls.Primitives.ScrollEventArgs e)
        {
            var ookiiDialog = new Ookii.Dialogs.Wpf.VistaSaveFileDialog();
            if (ookiiDialog.ShowDialog() == true)
            {
                var FileName = ookiiDialog.FileName;
                var path = ookiiDialog.InitialDirectory;

                new Export().Save("", ExportResult.Text);
            }
        }

        private void SaveFile_Click(object sender, RoutedEventArgs e)
        {
            if (string.IsNullOrWhiteSpace(ExportResult.Text))
            {
                System.Windows.Forms.MessageBox.Show("اسکریپتی برای ذخیره کردن وجود ندارد.");
            }
            else
            {
                var ookiiDialog = new Ookii.Dialogs.Wpf.VistaSaveFileDialog();
                if (ookiiDialog.ShowDialog() == true)
                {
                    var FileName = ookiiDialog.FileName;
                    var path = ookiiDialog.InitialDirectory;
                    if (!string.IsNullOrWhiteSpace(ExportResult.Text))
                    {
                        new Export().Save(FileName, ExportResult.Text);
                        System.Windows.Forms.MessageBox.Show($" فایل با موفقیت در مسیر زیر ذخیره شد\n {FileName}");
                    }

                    else
                        System.Windows.Forms.MessageBox.Show("اسکریپتی برای ذخیره کردن وجود ندارد.");
                }
            }
           
        }

        //private void Window_ContentRendered(object sender, EventArgs e)
        //{
        //    BackgroundWorker worker = new BackgroundWorker();
        //    worker.WorkerReportsProgress = true;
        //    worker.DoWork += worker_DoWork;
        //    worker.ProgressChanged += worker_ProgressChanged;

        //    worker.RunWorkerAsync();
        //}
        //void worker_DoWork(object sender, DoWorkEventArgs e)
        //{
        //    ExportResult.Text = new Export().Get(ookiiDialog.SelectedPath, sender);
        //    for (int i = 0; i < 100; i++)
        //    {
        //        (sender as BackgroundWorker).ReportProgress(i);
        //        Thread.Sleep(100);
        //    }
        //}

        //void worker_ProgressChanged(object sender, ProgressChangedEventArgs e)
        //{
        //    progressBar.Value = e.ProgressPercentage;
        //}
        //FolderItem ShellBrowseForFolder()
        //{
        //    Folder folder = shell.BrowseForFolder(Hwnd, "", 0, 0);
        //    if (folder != null)
        //    {
        //        FolderItem fi = (folder as Folder3).Self;
        //        return fi;
        //    }

        //    return null;
        //}
    }
}