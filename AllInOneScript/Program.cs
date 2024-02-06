using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AllInOneScript
{
    class Program
    {
        static void Main(string[] args)
        {

            // string   path = @"F:\KamaProject\Salary2\Kama.Aro.Salary\Kama.Aro.Salary.Infrastructure.DAL\DatabaseScript\StoredProcedures";
            string path = @"G:\KamaProjectGitLab\Pardakht\kama.aro.pardakht.api\Kama.Aro.Pardakht.Infrastructure.DAL\DatabaseScript\StoredProcedures";
            DirectoryInfo di = new DirectoryInfo(path);
            FileInfo[] fileInfos = di.GetFiles("*.sql", SearchOption.AllDirectories);
            string script = "";
            bool First = true;
            foreach (var fileInfo in fileInfos)
            {
                if(First)
                 script+= fileInfo.OpenText().ReadToEnd();
                else
                    script +="\n"+"GO"+ "\n"+ fileInfo.OpenText().ReadToEnd();
                First = false;
            }
            string OutFilePath = @"G:\KamaProject\Helper\AllInOne\AllInOneScript\Files\Kama.Aro.Pardakht.Procedures.sql";
            if (File.Exists(OutFilePath))
            {
                File.Delete(OutFilePath);
            }
            using (FileStream fs = File.Create(OutFilePath))
            {
                Byte[] ScriptByte = new UTF8Encoding(true).GetBytes(script);
                fs.Write(ScriptByte, 0, ScriptByte.Length);
            }  ;
            
        }
    }
}
