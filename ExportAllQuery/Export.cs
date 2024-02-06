using DocuSign.eSign.Model;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ExportAllQuery
{
   public  class Export
    {
        //public async Task<string> Get(string path)
        //{
           
        //}
        public void Save(string outFilePath,string script)
        {
            if (!outFilePath.Contains(".sql"))
                outFilePath= outFilePath + ".sql";
            if (File.Exists(outFilePath))
            {
                File.Delete(outFilePath);
            }
            using (FileStream fs = File.Create(outFilePath))
            {
                Byte[] ScriptByte = new UTF8Encoding(true).GetBytes(script);
                fs.Write(ScriptByte, 0, ScriptByte.Length);
            };
        }

    }
}
