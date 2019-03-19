using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.IO;
using System.Text;
using Microsoft.Build.Evaluation;
using System.Threading.Tasks;

namespace PleaseWork
{
    class Program
    {
        static void Main(string[] args)
        {
            Program p = new Program();
            p.RunScript();

        }
        public Program()
        {
            
        }
        private void RunScript()
        {
            // create Powershell runspace
            Runspace runspace = RunspaceFactory.CreateRunspace();

            // open it
            runspace.Open();

            // create a pipeline and feed it the script text
            Pipeline pipeline = runspace.CreatePipeline();

            string scriptFile = @"C:\Users\jeffrey.kennedy\source\repos\databases\Database1\ConsoleApp2\Scripts\CreateChangeScripts1.ps1";   // "..//Scripts//CreateChangeScripts1.ps1";
            string scriptText2 = LoadScript(scriptFile);
            pipeline.Commands.AddScript(scriptText2);

            // add an extra command to transform the script output objects into nicely formatted strings
            // remove this line to get the actual objects that the script returns. For example, the script
            // "Get-Process" returns a collection of System.Diagnostics.Process instances.
            pipeline.Commands.Add("Out-String");

            // execute the script
            Collection<PSObject> results = pipeline.Invoke();

            // close the runspace
            runspace.Close();

            // convert the script result into a single string
            StringBuilder stringBuilder = new StringBuilder();
            foreach (PSObject obj in results)
            {
                stringBuilder.AppendLine(obj.ToString());
            }


            
            Console.WriteLine(stringBuilder.ToString());
            Console.ReadLine();
        }
        private string LoadScript(string filename)
        {
            try
            {
                using (StreamReader sr = new StreamReader(filename))
                {

                    StringBuilder fileContents = new StringBuilder();

                    string curLine;

                    while ((curLine = sr.ReadLine()) != null)
                    {
                        fileContents.Append(curLine + "\n");
                    }

                    return fileContents.ToString();
                }
            }
            catch (Exception e)
            {
                string errorText = "The file could not be read:";
                errorText += e.Message + "\n";
                return errorText;
            }
        }
    }
}
